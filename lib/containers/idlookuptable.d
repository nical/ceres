module containers.idlookuptable;

debug { import std.stdio; }

// inspired from http://bitsquid.blogspot.ca/2011/09/managing-decoupling-part-4-id-lookup.html


/**
  ID lookup table.

  This container provides access to its elements through handles.
  The handle type is a template parameter that must alias an Index type and have an index property, 
  For example:

    struct Handle
    {
      alias ushort Index;
      Index index;
    }
*/
struct IDLookupTable(T,THandle) 
{

    alias THandle Handle;
    alias Handle.Index Index;
    alias _InternalData!(T,Index) InternalData;

    @property {
        Index length() const pure {
            return _length;
        }
        Index maxLength() const pure {
            return cast(Index) _data.length;
        }
        bool empty() const pure {
            return _length == 0;
        }
        inout(InternalData[]) elements() inout pure {
            return _data[0.._length];
        }
    }
    
    Handle add(T toCopy) pure {
        Index temp = _indices[_freeList].nextFreeIndex;
        Index newIdx = _freeList;
        // 
        _indices[newIdx].index = _length;
        // add object at the end of the data array
        _data[_length].data = toCopy;
        _data[_length].id   = newIdx;
        // update free list
        _freeList = cast(Index) (temp==0?_length+1:temp);
        // update length
        _length++;
        // create and return handle
        Handle result;
        result.index = cast(Index) (_offset + newIdx);
        return result;
    }

    Handle addEmpty() pure {
        return add(T.init);
    }
    
    bool remove(Handle handle) pure {
        if (!contains(handle)) return false;
        // local index of the removed object  
        Index idx = cast(Index) (handle.index - _offset);
        // move last element to replace the remived data
        _data[idx].data = _data[_length-1].data;
        _data[idx].id   = _data[_length-1].id;
        // update the index of the moved object
        _indices[_data[_length-1].id].index = idx;
        // clear the removed data 
        debug _data[_length-1].data = T.init;
        debug _data[_length-1].id   = 0;
        // add index of the removed object to free list
        _indices[idx].nextFreeIndex = _freeList;
        _freeList = idx;
        // reduce length
        _length -= 1;
        return true;
    }

    bool contains(Handle handle) pure {
        //debug{writeln("contains ", handle, " ?");}
        Index idx = cast(Index) (handle.index - _offset);
        if ((idx >= maxLength)||(handle.index < _offset)) {
            return false;
        }
        if (_data[_indices[idx].index].id!=idx) return false;

        Index it = _freeList;
        while (it != 0) {
            //debug writeln("-- ",it);
            if (it == idx) {
                return false;
            }
            it = _indices[it].nextFreeIndex;
        }
        return true;
    }

    T* get(Handle handle) pure {
        if (!contains(handle)) return null;
        return &_data[_indices[handle.index-_offset].index].data;
    }

    ref T opIndex(Handle handle) pure {
        auto res = get(handle);
        assert(res !is null);
        return *res;
    }

    void allocate(Index maxLen, Index indexOffset=1) pure {
        _indices.length = maxLen;
        _data.length = maxLen;
        _offset = indexOffset;
        _freeList = 0;
    }

private:
    
    InternalIndex!Index[]   _indices;
    InternalData[]    _data;
    Index   _offset;
    Index   _freeList;
    Index   _length;
} // IDLookupTable

private struct InternalIndex(Index)
{
    union {
        Index nextFreeIndex;
        Index index;
    };
}

private struct _InternalData(T,IndexT)
{
    T       data;
    IndexT  id;
}

void _dump(T)(ref T table) {
    writeln("freeList: ", table._freeList);
    write("indices: [");
    foreach (elt;table._indices) {
        write(" ", elt.index);
    }
    writeln(" ]");

    write("data: [");
    foreach (elt;table._data) {
        write(" (", elt.id,")",elt.data);
    }
    writeln("]");
    writeln();
}

unittest {
    struct Handle {
        alias ubyte Index;
        Index index;
    }

    IDLookupTable!(string,Handle) table;

    assert(table.length==0);
    assert(table.maxLength==0);

    table.allocate(10,1);

    table._dump();

    assert(table.length==0);
    assert(table.maxLength==10);

    auto foo = table.add("foo");
    table._dump();

    auto bar = table.add("bar");
    table._dump();
    writeln("foo:",foo);
    writeln("bar:",bar);
    
    assert(table.length==2);
    assert(table.maxLength==10);
    assert(table.contains(foo));
    assert(table.contains(bar));

    assert(table[foo]=="foo");
    assert(table[bar]=="bar");

    Handle h0 = {0};
    Handle h5 = {5};

    assert(!table.contains(h0));
    assert(!table.contains(h5));
    
    table._dump();

    writeln("add baz");
    auto baz = table.add("baz");
    assert(table.contains(baz));

    table._dump();
    writeln("remove bar");    
    assert(table.remove(bar));

    table._dump();

    assert(table.contains(foo));
    assert(table.contains(baz));
    assert(!table.contains(bar));
    assert(table.length==2);

    table._dump();
    writeln("add plop");
    auto plop = table.add("plop");

    table._dump();

    assert(table.contains(foo));
    assert(table.contains(baz));
    assert(table.contains(plop));

    assert(table.length==3);

    auto a = table.add("a");
    auto b = table.add("b");
    auto c = table.add("c");
    auto d = table.add("d");

    assert(table.contains(a));
    assert(table.contains(b));
    assert(table.contains(c));
    assert(table.contains(d));

    assert(table.length==7);

    assert(table.remove(b));
    assert(table.remove(c));

    assert(table.contains(a));
    assert(!table.contains(b));
    assert(!table.contains(c));
    assert(table.contains(d));

    assert(table.length==5);

    assert(table[a]=="a");
    assert(table[d]=="d");
    assert(table[foo]=="foo");
    assert(table[baz]=="baz");
    assert(table[plop]=="plop");

    int eltCount = 0;
    foreach (elt;table.elements) {
        assert( elt.data == "a"
             || elt.data == "d"
             || elt.data == "foo"
             || elt.data == "baz"
             || elt.data == "plop"
        );
        ++eltCount;
    }
    assert(eltCount==table.length);
}



// ----------------------------------------------------------------------------------


