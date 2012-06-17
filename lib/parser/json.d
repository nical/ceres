module parser.json;

import parser.common;

import std.array;
import std.ascii;
import std.variant;
import std.exception;

debug {
    import std.stdio;
    import utils.termcolors;
}


enum JSONTokenCode {
      INVALID=0
    , NAME=1, VALUE=2, COLON=4, COMMA=8
    , BEGIN_OBJECT=16|VALUE, END_OBJECT=32
    , BEGIN_ARRAY=64|VALUE, END_ARRAY=128
    , BOOL = VALUE|256
    ,   TRUE  = BOOL|1024
    ,   FALSE = BOOL|2048
    , NULL = VALUE|4096
    , STRING = VALUE|8192
    , NUMBER = VALUE|16384
}


int CharToJSONTokenCode(char c) {
    switch(c) {
        case ':': return cast(int)JSONTokenCode.COLON;
        case ',': return cast(int)JSONTokenCode.COMMA;
        case '{': return cast(int)JSONTokenCode.BEGIN_OBJECT;
        case '}': return cast(int)JSONTokenCode.END_OBJECT;
        case '[': return cast(int)JSONTokenCode.BEGIN_ARRAY;
        case ']': return cast(int)JSONTokenCode.END_ARRAY;
        default : return cast(int)JSONTokenCode.INVALID;
    }
}

int StrToJSONTokenCode(string s) {
    if (s.length==1) return CharToJSONTokenCode(s[0]);
    switch(s) {
        case "true" : return cast(int)JSONTokenCode.TRUE;
        case "false": return cast(int)JSONTokenCode.FALSE;
        case "null" : return cast(int)JSONTokenCode.NULL;
        default : return cast(int)JSONTokenCode.INVALID;
    }
}

template TokenCode(char c) {
    enum : int {
        TokenCode = CharToJSONTokenCode(c)
    };
}
template TokenCode(string s) {
    enum : int {
        TokenCode = StrToJSONTokenCode(s)
    };
}

class JSONLexerException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

struct JSONLexer {
    enum {NONE=0, SKIP_EOL=1};
    alias int LexerFlags;

    this(string aSrc = "")
    {
        src = aSrc;
    }

    bool tokenize(out Token result)
    {
        skipWhite(src);
        if (empty) return false;
        if (handleSingleCharOp!':'(result)) return true;
        if (handleSingleCharOp!','(result)) return true;
        if (handleSingleCharOp!'['(result)) return true;
        if (handleSingleCharOp!']'(result)) return true;
        if (handleSingleCharOp!'{'(result)) return true;
        if (handleSingleCharOp!'}'(result)) return true;
        
        if (front == '"') {
            result.format = Token.STRING;
            result.str ~= front;
            advance();
            while (front != '"') {
                result.str ~= front;
                advance();
            }
            result.str ~= '"';
            advance();
            return true;
        }
        if (isAlphaNumOrUnderscore(front)) {
            if (src.length>3 && src[0..4]=="null") {
                result.format = Token.CODE;
                result.code = JSONTokenCode.NULL;
                advance(4);
                return true;
            }
            if (src.length>3 && src[0..4]=="true") {
                result.format = Token.CODE;
                result.code = JSONTokenCode.TRUE;
                advance(4);
                return true;
            }
            if (src.length>4 && src[0..5]=="false") {
                result.format = Token.CODE;
                result.code = JSONTokenCode.FALSE;
                advance(5);
                return true;
            }
            result.format = Token.STRING;
            while (isAlphaNumOrUnderscore(front)||front=='.') {
                result.str ~= front;
                advance();
                if (empty) return false;
            }
            return true;
        }
        throw new JSONLexerException("syntax error: near '"~src~"'");
    }

    private bool handleSingleCharOp(char op)(ref Token token)
    {
        if (src.front == op) {
            token.format = Token.CODE;
            token.code = TokenCode!op;
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
enum JSONParserContextType{BASE=0, OBJECT=32, ARRAY=128};

struct JSONParser(Source)
{
    
    this(Source source) {
        src = source;
        expecting=TokenType.VALUE;
        currentName="";
    }

    bool advance() {        
        Token token;
        if (lexer.empty) {
            if (!getLineFrom!Source(src, lexer.src)) {
                return false; // end of the stream
            }
        }

        lexer.tokenize(token);
        writeln(GREEN, token.toString(), RESET);

        if (onToken) onToken(state, token);

        if (token.isCode(TokenType.BEGIN_OBJECT)) {
            assert(expecting&TokenType.VALUE);
            state.push(JSONContext(JSONParserContextType.OBJECT,currentName));
            if (onBeginObject) onBeginObject(state);
            expecting = TokenType.NAME
                      | TokenType.END_OBJECT;
            currentIndex = 0;
        
        } else if (token.isCode(TokenType.END_OBJECT)) {
            assert(expecting&TokenType.END_OBJECT);
            string name = state.name;
            if (onEndObject) onEndObject(state);
            state.pop(); 
            if (state.depth > 0) {
                expecting = TokenType.COMMA | state.contextEndCode;
                currentIndex = state.index;
            } else {
                // should be the last token
                expecting = TokenType.NULL;
            }
        
        } else if (token.isCode(TokenType.BEGIN_ARRAY)) {
            assert(expecting&TokenType.VALUE);
            state.push(JSONContext(JSONParserContextType.ARRAY,currentName));
            if(onBeginArray) onBeginArray(state);
            currentName = null;
            currentIndex = 0;
            expecting = TokenType.VALUE
                      | TokenType.BEGIN_OBJECT
                      | TokenType.BEGIN_ARRAY
                      | TokenType.END_ARRAY;
        
        } else if (token.isCode(TokenType.END_ARRAY)) {
            assert(expecting&TokenType.END_ARRAY);
            string name = state.name;
            state.pop();
            if (onEndObject) onEndArray(state);
            if (state.depth > 0) {
                expecting = TokenType.COMMA | state.contextEndCode;
                currentIndex = state.index;
            } else {
                expecting = TokenType.NULL; // should be the last token
            }

        } else if (token.isCode(TokenType.COLON)) {
            assert(expecting & TokenType.COLON);
            expecting = TokenType.VALUE;

        } else if (token.isCode(TokenType.COMMA)) {
            assert(expecting & TokenType.COMMA);
            expecting = (state.inObject ? TokenType.NAME : TokenType.NULL)
                      | (state.inArray ? TokenType.VALUE : TokenType.NULL);
            ++currentIndex;          

        } else {
            if (expecting&TokenType.VALUE) {
                if (onBasicValue) onBasicValue(state, token.str);
                expecting = state.contextEndCode
                          | TokenType.COMMA;
            } else {
                assert(token.format == Token.STRING);
                assert(expecting&TokenType.NAME);
                if (token.str.length>2 && token.str[0]=='"') {
                    token.str = token.str[1..$-1];
                }
                if (onName) onName(state,token.str);
                currentName = token.str;
                expecting=TokenType.COLON;
            }
        }
        return true;
    }

    Source src;
    JSONLexer lexer;
    
    alias void delegate(JSONParserState state) Callback;
    alias void delegate(JSONParserState state, string name) CallbackString;
    alias void delegate(JSONParserState state, Token tok) CallbackToken;

    CallbackToken onToken;
    CallbackString onName;
    CallbackString onBasicValue;
    Callback onBeginObject;
    Callback onEndObject;
    Callback onBeginArray;
    Callback onEndArray;
private:
    TokenType expecting;
    string  currentName;
    uint    currentIndex;
    //JSONContext[]   stack;
    JSONParserState state;
}

struct JSONParserState 
{
    
    @property {
        JSONParserState parent() {
            assert(hasParent);
            return JSONParserState(stack[0..$-2]);
        }
        bool hasParent() const {
            return stack.length>1;
        }
        string name() const {
            return stack[$-1].name;
        }
        uint index() const {
            return stack[$-1].index;
        }
        ref Variant userData() {
            return stack[$-1].userData;
        }
        bool inObject() const {
            return stack[$-1].type==JSONParserContextType.OBJECT;
        }
        bool inArray() const {
            return stack[$-1].type==JSONParserContextType.ARRAY;
        }
        bool inBase() const {
            return stack[$-1].type==JSONParserContextType.BASE;
        }
        uint depth() const {
            return cast(uint) stack.length;
        }
    }

private:
    this(JSONContext[] aStack) {
        stack = aStack;
    }
    void push(JSONContext ctx) {
        stack ~= ctx;
    }
    void pop() {
        stack.length-=1;
    }
    @property TokenType contextEndCode() const {
        return cast(TokenType)stack[$-1].type;
    }
    JSONContext[] stack;
}

struct JSONContext
{
    ubyte  type;
    string name;
    uint   index;
    Variant userData;
    @property TokenType contextEnd() {
        return cast(TokenType) type;
    }
}


unittest {
   void AssertTokenCode(ref JSONLexer l, int expected) {
        Token token;
        assert( l.tokenize(token)
            , RED ~ "error: unexpected end of stream"
            ~ RESET);
        writeln(BLUE, token.toString(),RESET, " expecting code ", expected);
        assert( token.format == Token.CODE
            , RED~"error, expected code token format. "~RESET);
        assert( token.code==expected
            , RED ~ "Wrong token"~ RESET);
    }
    void AssertTokenString(ref JSONLexer l, string expected) {
        Token token;
        assert( l.tokenize(token)
            , RED ~ "error: unexpected end of stream"
            ~ RESET);
        assert( token.format == Token.STRING
            , RED~"error, expected code token format. "~RESET);
        assert( token.str==expected
            , RED ~ "Wrong token"~ RESET);
    }

    import std.stdio;
    writeln(" -- parser.json.unittest.");

    Token tok;
    auto l3 = JSONLexer("{  foo : {array: [null,2.56    , false,true], \"a\":\"A\"\n}}");
    AssertTokenCode(l3,TokenCode!"{");
    AssertTokenString(l3,"foo");
    AssertTokenCode(l3,TokenCode!":");
    AssertTokenCode(l3,TokenCode!"{");
    AssertTokenString(l3,"array");
    AssertTokenCode(l3,TokenCode!":");
    AssertTokenCode(l3,TokenCode!"[");
    AssertTokenCode(l3,TokenCode!"null");
    AssertTokenCode(l3,TokenCode!",");
    assert(l3.tokenize(tok));
    AssertTokenCode(l3,TokenCode!",");
    AssertTokenCode(l3,TokenCode!"false");
    AssertTokenCode(l3,TokenCode!",");
    AssertTokenCode(l3,TokenCode!"true");
    AssertTokenCode(l3,TokenCode!"]");
    AssertTokenCode(l3,TokenCode!",");
    assert(l3.tokenize(tok));
    AssertTokenCode(l3,TokenCode!":");
    assert(l3.tokenize(tok));
    AssertTokenCode(l3,TokenCode!"}");
    AssertTokenCode(l3,TokenCode!"}");

    string src_a = "{foo:{bar:42,plop:[1,2,3]},baz:false}";
    auto p1 = JSONParser!string(src_a);
    string src_b;
   
    p1.onToken = (JSONParserState, Token token){
        if (token.isCode(TokenCode!",")) {
            src_b ~= ",";
            write(",");
        }
        else if (token.isCode(TokenCode!":")) {
            src_b ~= ":";
            write(":");
        }
    };
    bool dbgprint = false;

    p1.onBeginArray = (JSONParserState state){
        if (dbgprint) write(YELLOW,"[",RESET);
        src_b~='[';
    };

    p1.onEndArray = (JSONParserState state){
        if (dbgprint) write(YELLOW,"]",RESET);
        src_b~=']';
    };
    
    p1.onBeginObject = (JSONParserState state){
        if (dbgprint) write(GREEN,"{",RESET);
        src_b~='{';
    };

    p1.onEndObject = (JSONParserState state){
        if (dbgprint) write(GREEN,"}",RESET);
        src_b~='}';
    };
    
    p1.onBasicValue = (JSONParserState,string name){
        if (dbgprint) write(RED,name,RESET);
        //src_b~=name;
    };

    writeln(BLUE, p1.src, RESET);
    while (p1.advance()) {}
    writeln();
    //assert(src_a==src_b);

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