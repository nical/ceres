module parser.json;

import parser.common;

import std.array;
import std.ascii;
import std.variant;

debug {
    import std.stdio;
    import utils.termcolors;
}

struct JSONLexer
{
    enum {NONE=0, SKIP_EOL=1};
    alias int LexerFlags;

    this(string aSrc = "")
    {
        src = aSrc;
    }

    bool tokenize(out string result)
    {
        result = "";
        while (true) {
            skipWhite(src);
            if (empty) return false;
            foreach (c;":,[]{}") {
                if (handleSingleCharOp(c,result)) return true;
            }
            if (front == '"') {
                result ~= front;
                advance();
                while (front != '"') {
                    result ~= front;
                    advance();
                }
                result ~= '"';
                advance();
                return true;
            }
            if (isAlphaNumOrUnderscore(front)) {
                while (isAlphaNumOrUnderscore(front)||front=='.') {
                    result ~= front;
                    advance();
                    if (empty) return false;
                }
                return true;
            }
            assert( empty, "syntax error: near " ~ src);
        }
    }

    private bool handleSingleCharOp(char op, ref string token)
    {
        if (src.front == op) {
            token = ""~op;
            advance();
            return true;
        }
        return false;
    }

    bool advance(uint n = 1) {
        if (src.length>=n) {
            src=src[n..$];
            return true;
        }
        return false;
    }

    @property char front() {
        debug { 
            if (empty) writeln(RED, "lexer error: using front on empty stream.", RESET);
        }
        return src[0];
    }

    @property char next() {
        return src[1];
    }

    @property bool empty() {
        return src.length==0;
    }

    string src;
}

bool getLineFrom(T)(ref T src, ref string line) {
    static if (is(T==File)) {
        return (src.readln(line) != 0);
    }
    static if (is(T==string)) {
        if (src.length>0) {
            line = src;
            src = "";
            return true;
        }
        return false;
    }
    return false;
}

enum TokenType {
      NULL=0
    , NAME=1, VALUE=2, COLON=4, COMMA=8
    , BEGIN_OBJECT=16|VALUE, END_OBJECT=32
    , BEGIN_ARRAY=64|VALUE, END_ARRAY=128
};

struct JSONParser(Source)
{
    enum {BASE=0, OBJECT=32, ARRAY=128};

    this(Source source) {
        src = source;
        expecting=TokenType.VALUE;
        currentName="";
    }

    bool advance() {
        string token;
        if (lexer.empty) {
            if (!getLineFrom!Source(src, lexer.src)) {
                return false; // end of the stream
            }
        }

        lexer.tokenize(token);
        
        if (onToken) onToken(stack, token);
                
        if (token=="{") {
            assert(expecting&TokenType.VALUE);
            if (onBeginObject) onBeginObject(stack, currentName);
            stack ~= JSONContext(OBJECT,currentName);
            expecting = TokenType.NAME
                      | TokenType.END_OBJECT;
        } else if (token=="}") {
            assert(expecting&TokenType.END_OBJECT);
            string name = stack[$-1].name;
            stack.length -= 1; 
            if (onEndObject) onEndObject(stack, name);
            if (stack.length > 0) {
                expecting = TokenType.COMMA | stack[$-1].contextEnd;
            } else {
                expecting = TokenType.NULL; // should be the last token
            }
        } else if (token=="[") {
            assert(expecting&TokenType.VALUE);
            if(onBeginArray) onBeginArray(stack, currentName);
            stack ~= JSONContext(ARRAY,currentName);
            currentName="<index>";
            expecting = TokenType.VALUE
                      | TokenType.BEGIN_OBJECT
                      | TokenType.BEGIN_ARRAY
                      | TokenType.END_ARRAY;
        } else if (token=="]") {
            assert(expecting&TokenType.END_ARRAY);
            string name = stack[$-1].name;
            stack.length -= 1;
            if (onEndObject) onEndArray(stack, name);
            if (stack.length > 0) {
                expecting = TokenType.COMMA | stack[$-1].contextEnd;
            } else {
                expecting = TokenType.NULL; // should be the last token
            }
        } else if (token==":") {
            assert(expecting & TokenType.COLON);
            expecting = TokenType.VALUE;
        } else if (token==",") {
            assert(expecting & TokenType.COMMA);
            expecting = (stack[$-1].type==OBJECT ? TokenType.NAME : TokenType.NULL)
                      | (stack[$-1].type==ARRAY ? TokenType.VALUE : TokenType.NULL);
                      
        } else {
            if (expecting&TokenType.VALUE) {
                if (onBasicValue) onBasicValue(stack, token);
                expecting = stack[$-1].contextEnd
                          | TokenType.COMMA;
            } else {
                assert(expecting&TokenType.NAME);
                if (token.length>2 && token[0]=='"') {
                    token = token[1..$-1];
                }
                if (onName) onName(stack,token);
                currentName = token;
                expecting=TokenType.COLON;
            }
        }
        return true;
    }

    Source src;
    JSONLexer lexer;
    
    alias void delegate(JSONContext[] stack, string name) Callback;

    Callback onName;
    Callback onToken;
    Callback onBasicValue;
    Callback onBeginObject;
    Callback onEndObject;
    Callback onBeginArray;
    Callback onEndArray;
private:
    TokenType expecting;
    string currentName;
    JSONContext[] stack;
}

struct JSONParserState 
{

    JSONParserState parent() {
        // TODO
        assert(false);
    }

}

struct JSONContext
{
    ubyte  type;
    string name;
    Variant userData;
    @property TokenType contextEnd() {
        return cast(TokenType) type;
    }
}


unittest {

    void AssertToken(ref JSONLexer l, string expected) {
        string token;
        assert( l.tokenize(token)
            , RED ~ "error: end of stream when expecting '"
            ~ RESET~ expected~ RED~ "'"
            ~ RESET);
        assert( token==expected
            , RED ~ "Wrong token '"
            ~ RESET~ token
            ~ RED ~ "', expected "
            ~ RESET~ expected~RED~"'"
            ~ RESET);
    }

    import std.stdio;
    writeln(" -- parser.json.unittest.");

    string token;

    auto l1 = JSONLexer("{foo:\"bar\"}");

    AssertToken(l1,"{");
    AssertToken(l1,"foo");
    AssertToken(l1,":");
    AssertToken(l1,"\"bar\"");
    AssertToken(l1,"}");
    assert(!l1.tokenize(token));

    auto l2 = JSONLexer("{  foo : {array: [1,2.56    , 3,4], \"a\":\"A\"\n}}");
    AssertToken(l2,"{");
    AssertToken(l2,"foo");
    AssertToken(l2,":");
    AssertToken(l2,"{");
    AssertToken(l2,"array");
    AssertToken(l2,":");
    AssertToken(l2,"[");
    AssertToken(l2,"1");
    AssertToken(l2,",");
    AssertToken(l2,"2.56");
    AssertToken(l2,",");
    AssertToken(l2,"3");
    AssertToken(l2,",");
    AssertToken(l2,"4");
    AssertToken(l2,"]");
    AssertToken(l2,",");
    AssertToken(l2,"\"a\"");
    AssertToken(l2,":");
    AssertToken(l2,"\"A\"");
    AssertToken(l2,"}");
    AssertToken(l2,"}");
    assert(!l2.tokenize(token));

    string src_a = "{foo:{bar:42,plop:[1,2,3]},baz:false}";
    auto p1 = JSONParser!string(src_a);
    string src_b;

    p1.onName = (JSONContext[] stack, string name){
        write(BLUE,name,RESET);
        src_b~=name;
    };
    
    p1.onToken = (JSONContext[],string token){
        if (token == ",") {
            src_b ~= ",";
            write(",");
        }
        else if (token == ":") {
            src_b ~= ":";
            write(":");
        }
    };
    
    p1.onBeginArray = (JSONContext[],string name){
        write(YELLOW,"[",RESET);
        src_b~='[';
    };

    p1.onEndArray = (JSONContext[],string name){
        write(YELLOW,"]",RESET);
        src_b~=']';
    };
    
    p1.onBeginObject = (JSONContext[],string name){
        write(GREEN,"{",RESET);
        src_b~='{';
    };

    p1.onEndObject = (JSONContext[],string name){
        write(GREEN,"}",RESET);
        src_b~='}';
    };
    
    p1.onBasicValue = (JSONContext[],string name){
        write(RED,name,RESET);
        src_b~=name;
    };

    writeln(BLUE, p1.src, RESET);
    while (p1.advance()) {}
    writeln();
    assert(src_a==src_b);

    writeln(" -- parser.json.unittest done.");
}

unittest {
    import std.stdio;
    
    class LevelLayer {
        string name;
        string tileSetImg;
        int width;
        int height;
        int[] indices;
    }

    class Level {
        string name;
        LevelLayer[] layers;
    }
    

    auto srcFile = File("jsonTest.json");
    auto parser = JSONParser!File(srcFile);

    parser.onBeginObject = (JSONContext[] stack, string name) {
        if (name == "layers") {

        }
    };
}

/+

onBeginArray: {
    if (context.inObject && context.name=="indices")
    auto layer = context.parent.userData.get!LevelLevel();
    if (layer.width*layer.height > 0) {
        layer.indices = new int[layer.width*layer.height];
        layer.preAllocatedIndices = true;
    } else {
        layer.preAllocatedIndices = false;
    }
}

onBeginObject: {
    if (context.inArray 
        && context.parent.inObject
        && context.parent.name=="layers") {
        auto layers = context.parent.userData.get!(Layer[])();
        auto l = new Layer;
        layers ~= l;
        context.userData = l;
    }
}



+/