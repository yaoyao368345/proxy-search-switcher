// An aligned Win64 memory model for exercising ownership, not a native ABI proof.
function fakeCtypes(settings={}){
  let next=0x1000000000000000n,lastError=0;
  const slots=new Map(),objects=new Map(),opened=[],closed=[],freed=[],read=[],queries=[];
  const align=(n,a)=>(n+BigInt(a)-1n)/BigInt(a)*BigInt(a);
  const allocate=(size,alignment)=>{next=align(next,alignment);const address=next;next+=BigInt(size+16);return address;};
  class Pointer{
    constructor(address,type){this.addressValue=BigInt(address);this.type=type;}
    isNull(){return this.addressValue===0n;}
    get contents(){if(this.type.target?.kind === 'struct')return objects.get(this.addressValue);if(slots.has(this.addressValue))return slots.get(this.addressValue).get();return objects.get(this.addressValue);}
    set contents(v){slots.get(this.addressValue).set(v);}
    readString(){read.push(this.addressValue);if(settings.readStringThrows)throw Error('raw-native-private-detail');return objects.get(this.addressValue);}
  }
  function pointerType(target){
    const Type=function(value){return value instanceof Pointer?new Pointer(value.addressValue,Type):new Pointer(value||0,Type);};
    Object.assign(Type,{size:8,alignment:8,kind:'pointer',target});Object.defineProperty(Type,'ptr',{get(){return pointerType(Type);}});return Type;
  }
  function primitive(name,size,alignment){
    const Type=function(value=0){const address=allocate(size,alignment);const data={value,address:()=>new Pointer(address,Type.ptr)};slots.set(address,{get:()=>data.value,set:v=>{data.value=v;}});return data;};
    Object.assign(Type,{size,alignment,kind:'scalar',ctypeName:name});Object.defineProperty(Type,'ptr',{get(){return pointerType(Type);}});
    Type.array=n=>arrayType(Type,n);return Type;
  }
  function arrayType(Type,n){
    const ArrayType=function(){const address=allocate(Type.size*n,Type.alignment),array=[];
      for(let i=0;i<n;i++)array[i]=Type.kind==='struct'?Type.at(address+BigInt(i*Type.size)):0;
      array.addressOfElement=i=>new Pointer(address+BigInt(i*Type.size),Type.ptr);array.readString=()=>'';return array;
    };Object.assign(ArrayType,{size:Type.size*n,alignment:Type.alignment,kind:'array'});return ArrayType;
  }
  const c={winapi_abi:'win64',uint32_t:primitive('DWORD',4,4),int32_t:primitive('LONG',4,4),char16_t:primitive('WCHAR',2,2),uint64_t:primitive('U64',8,8),uintptr_t:primitive('UINTPTR',8,8),intptr_t:primitive('INTPTR',8,8)};
  Object.defineProperty(c,"winLastError",{get:()=>lastError,configurable:true});
  c.voidptr_t=pointerType(null);
  c.StructType=(name,fields)=>{
    let size=0,alignment=1;const layout=[];
    for(const field of fields){const [key,Type]=Object.entries(field)[0];size=Number(align(BigInt(size),Type.alignment));layout.push({key,Type,offset:size});size+=Type.size;alignment=Math.max(alignment,Type.alignment);}
    size=Number(align(BigInt(size),alignment));
    const Type=function(){return Type.at(allocate(size,alignment));};
    Object.assign(Type,{size,alignment,kind:'struct',ctypeName:name,layout});Type.ptr=pointerType(Type);Type.array=n=>arrayType(Type,n);
    Type.at=address=>{
      const data={address:()=>new Pointer(address,Type.ptr),addressOfField:key=>{const field=layout.find(v=>v.key===key);return new Pointer(address+BigInt(field.offset),field.Type.ptr);}};
      for(const field of layout){let value=field.Type.kind==='pointer'?field.Type():0;
        Object.defineProperty(data,field.key,{get:()=>value,set:v=>{value=v;}});
        slots.set(address+BigInt(field.offset),{get:()=>value,set:v=>{value=v;}});
      }objects.set(address,data);return data;
    };return Type;
  };
  c.cast=(value,Type)=>{
    if(Type.kind==='pointer')return new Pointer(value.addressValue,Type);
    if(Type===c.uintptr_t || Type===c.intptr_t)return {value:value.addressValue};
    throw Error('unsupported test cast');
  };
  function string(value){const address=allocate(16,8);objects.set(address,value);return c.char16_t.ptr(new Pointer(address));}
  c.open=path=>{
    if(settings.openFailure && path.endsWith(settings.openFailure))throw Error('private-dll-path');
    opened.push(path);
    return {close(){closed.push(path);if(settings.closeFailure && path.endsWith(settings.closeFailure))throw Error('private-close-error');},declare(name){
      if(settings.declareFailure===name)throw Error('private-declare-error');
      if(name==='InternetQueryOptionW')return (_handle,option,listPointer,sizePointer)=>{
        const list=objects.get(listPointer.addressValue),item=objects.get(list.options.addressValue);queries.push(item.option);
        if(settings.onQuery)return settings.onQuery({list,item,sizePointer,string,c,queries,setError:n=>{lastError=n;}});
        if(item.option===10)item.value=3;else item.value=item.option===2?string('127.0.0.1:7897'):c.char16_t.ptr();
        return 1;
      };
      if(name==='GlobalFree')return pointer=>{freed.push(pointer.addressValue);return settings.freeFailure?pointer:c.voidptr_t();};
      if(name==='GetLastError')return ()=>{lastError=0;return 0;};
      return ()=>1;
    }};
  };
  return {c,opened,closed,freed,read,queries,string};
}
module.exports={fakeCtypes};
