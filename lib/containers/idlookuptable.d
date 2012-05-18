module containers.idlookuptable;

debug { import std.stdio; }

// inspired from http://bitsquid.blogspot.ca/2011/09/managing-decoupling-part-4-id-lookup.html


/**
  ID lookup table.

  This container provides access to its elements through handles.
  The handle type is a template parameter that must alias Index and ServiceID types and have index and ServiceID properties, 
  For example:

    struct Handle
    {
      alias ushort Index;
      alias ushort ServiceID;
      Index index;
      ServiceID service;
    }
*/
struct IDLookupTable(T,THandle) 
{

  alias THandle Handle;
  alias Handle.Index Index;
  alias Handle.ServiceID ServiceID;
  
  this (ServiceID service) {
    _serviceID = service;
  }


  /**
  Returns true if there is an element for this handle in the container.
  */
  bool contains(Handle h) const {
    if (h.service!=_serviceID 
        || h.index==0 
        || h.index>=_ids.length) {
      return false;
    }
    Index it = firstFreeHandle;
    while (it != 0) {
      if (it == h.index) {
        return false;
      }
      it = _ids[it];
    }
    return true;
  }

  /**
  Access an element using its handle.

  The reference to the element should not be kept because elements can be moves in the container.
  */
  inout(T)* get(Handle h) inout {
    if(!contains(h)) return null;
    return &_objects[_ids[h.index]].object;
  }

  /**
  Access an element using its handle.

  The reference to the element should not be kept because elements can be moves in the container.
  */
  ref inout(T) opIndex(Handle h) inout {
    assert(h.service == _serviceID);
    return _objects[_ids[h.index]].object;
  }

  @property {

    /**
    Returns the number of elements in the container.
    */
    Index length() const {
      return cast(Index) _objects.length;
    }

    /**
    Optional callback function invoked on every removal.
    */
    ref auto onRemove() {
      return _rmCallback;
    }


    ServiceID serviceID() const {
      return _serviceID;
    }

  } // properties

  /**
  Adds a copy of the element passed in parameter and returns a handle to access it.
  */
  Handle add(T obj) {
    Handle res = add();
    *get(res) = obj;
    return res;
  }

  /**
  Adds an empty element to the container and returns a handle to access it;
  */
  Handle add() 
  out(h) {
    assert(_objects[_ids[h.index]].handle == h.index);
  } body {
    if (firstFreeHandle==0) {
      Index res = cast(Index)_ids.length;
      _ids ~= cast(Index)_objects.length;
      _objects.length = _objects.length+1;
      _objects[$-1].handle = res; 
      return createHandle(res);
    }

    Index temp = _ids[firstFreeHandle];
    Index result = firstFreeHandle; 
    
    _ids[result] = cast(Index)_objects.length;
    
    _objects.length = _objects.length+1;
    _objects[$-1].handle = result; 
    
    _ids[FREE_LIST] = temp;

    return createHandle(result);
  }

  /**
  Removes an element from the conatianer.

  Removing an element can reorganize the objects within the container, 
  so one should never keep pointers or references to to an element from 
  prior to a call to remove. 
  */
  void remove(Handle h) {
    assert(contains(h));
    
    // idx of the object to remove
    Index idx = _ids[h.index];
    if(_rmCallback) _rmCallback(_objects[idx].object);
    
    // set free list
    _ids[h.index] = firstFreeHandle;
    _ids[FREE_LIST] = h.index;
    // move last object to keep the object list continguous
    _objects[idx] = _objects[$-1];

    // fix the index at the handle pointing to the just moved object
    if(_objects.length > 1) {
       _ids[_objects[idx].handle] = idx;
    }

    _objects.length -= 1;
  }

  /**
  Clears the container after calling onRemove callback on each element. 
  */
  void removeAll() {
    if (_rmCallback) {
      foreach(ref obj;_objects) {
        _rmCallback(obj.object);
      }
    }

    _objects.length = 0;
    _ids = [0];
  }
  
  /**
  Debug facility
  */
  void dumpIds() const {
    debug {
      Index[] freeIds = [0];
      
      for (Index it = _ids[0]; it!=0; it=_ids[it]) {
        freeIds ~= it;
      }
    
      write("[");
      //writeln(_ids);
      foreach(uint i,Index handle; _ids) {
        bool found = false;
        foreach(freeId;freeIds) {
          if(i==freeId)
            found = true;
        }
        if(!found) {
          write(_ids[i], " ");
        } else {
          write("\033[1;33m",_ids[i], "\033[0m ");
        }
      }
      writeln("]");   
    } // debug
  }
  /**
  Debug facility
  */
  void dumpObjects() const {
    debug {
      //
    }
  }

  /**
  Debug facility
  */
  void dump() const {
    debug {
      write("|  ids: ");
      dumpIds();
      //write("|  objects: ");
      //dumpObjects();
    }
  }

private:
  enum { FREE_LIST=0 };
  struct T_handle {
    Index handle;
    T object;
  }

  /**
  Creates a handle from an index.
  Intended for internal use mostly
  */
  Handle createHandle(Index index) {
    return Handle(index, _serviceID);
  }


  @property ushort firstFreeHandle() const { return _ids[0]; }

  Handle.Index[]        _ids = [0];
  T_handle[]            _objects;
  void function(ref T)  _rmCallback = null;
  Handle.ServiceID      _serviceID;

}// IDLookupTable






// ----------------------------------------------------------------------------------




unittest {
  import std.stdio;

  struct Handle
  {
    alias ushort Index;
    alias ushort ServiceID;
    Index index;
    ServiceID service;
  }


  writeln("containers.lookuptable.unittest");

  IDLookupTable!(string,Handle) table;

  table.onRemove = function void (ref string s) {
    writeln("cb: removing ", s);
  };

  assert(table.length==0);
  auto foo = table.add("foo");

  table.dump();

  assert(table.length==1);
  assert(foo.index==1);
  assert(table[foo] == "foo");
  foreach(i ; 0..10) {
    if ( i!=foo.index) {
      assert(!table.contains(table.createHandle(cast(ushort)i)));
    }
  }

  auto bar = table.add("bar");
  table.dump();
  auto baz = table.add("baz");
  table.dump();
  auto plop = table.add("plop");

  foreach(i ; 0..10) {
    if (i!=foo.index 
        && i!=bar.index 
        && i!=baz.index 
        && i!=plop.index) {
      assert(!table.contains(table.createHandle(cast(ushort)i)));
    }
  }

  assert(table[foo]  == "foo");
  assert(table[bar]  == "bar");
  assert(table[baz]  == "baz");
  assert(table[plop] == "plop");

  assert(table.length == 4);

  table.dump();


  writeln("foo=",foo," baz=",baz," plop=",plop);
  writeln("remove bar");
  table.remove(bar);

  table.dump();
  writeln("foo=",foo," baz=",baz," plop=",plop);

  assert(table[foo]  == "foo");
  assert(table[baz]  == "baz");
  assert(table[plop] == "plop");

  assert(table.length == 3);

  writeln("rm plop");
  table.remove(plop);

  writeln("----");
  table.dump();

  assert(table[foo]  == "foo");
  assert(table[baz]  == "baz");
  
  auto hi = table.add("hi");

  table.dump();
  
  assert(table[foo]  == "foo");
  assert(table[baz]  == "baz");
  assert(table[hi]   == "hi");
  
  assert(table.contains(foo));
  assert(table.contains(baz));
  assert(table.contains(hi));

  writeln("rm ALL THE THINGS!");
  table.remove(hi);
  table.dump;
  table.remove(foo);
  table.dump;
  table.remove(baz);

  assert(table.length==0);

  table.dump;

  writeln("add new stuff");
  
  auto a = table.add("A");
  auto b = table.add("B");
  auto c = table.add("C");
  auto d = table.add("D");
  auto e = table.add("E");
  auto f = table.add("F");

  table.dump();

  assert(table.contains(a));
  assert(table.contains(b));
  assert(table.contains(c));
  assert(table.contains(d));
  assert(table.contains(e));
  assert(table.contains(f));  

  assert(table[a]=="A");
  assert(table[b]=="B");
  assert(table[c]=="C");
  assert(table[d]=="D");
  assert(table[e]=="E");
  assert(table[f]=="F");

  assert(table.length==6);

  table.removeAll();

  assert(table.length==0);

  writeln("..done");

}

