module gl.shaderlexer;

import std.stdio;
import std.array;
import std.ascii;

debug {
import utils.termcolors;
}

struct ShaderLexer {
    this(string source) {
        src=source;
    }

    enum {NONE=0, SKIP_EOL=1};
    alias int LexerFlags;

    bool tokenize(out string token, LexerFlags flags=SKIP_EOL) {
        string result = "";
        while (true) {
            skipWhite(flags);
            if (!empty && front=='\n') {
                token="\n";
                return true;
            }

            if (empty) return false;

            if (front=='/') {
                // one-line comments
                if (front=='/') {
                    skipLine();
                    if (empty) return false;
                }
                // multiLine-comments
                if (front=='*') {
                    advance();
                    while(front!='*' || front!='/') {
                        advance();
                    }
                    advance(2);
                }
                // "/="
                if (front=='=') {
                    token="/=";
                    advance(2);
                    return true;
                }

                token="/";
                advance();
                return true;
            }
            if (front=='#') {
                token ~= '#';
                advance();
            }
            if (isAlphaNumOrUnderscore(front)) {
                while (isAlphaNumOrUnderscore(front)) {
                    token ~= front;
                    advance();
                    if(src.length==0) return false;
                }
                return true;
            }
            
            if (handleOp('|',"|=",token)) return true;
            if (handleOp('&',"&=",token)) return true;
            if (handleOp('+',"+=",token)) return true;
            if (handleOp('-',"-=",token)) return true;
            if (handleOp('*',"=",token)) return true;
            if (handleOp('/',"=",token)) return true;
            foreach(c;"<>!=~^") {
                if (handleOp(c,"=",token)) return true;
            }
            foreach(c;".;,()[]{}:%$?") {
                if (handleOp(c,"",token)) return true;
            }
        } // lopp
        return false; //never reached
    }

    bool advance(uint n = 1) {
        if(src.length>=n) {
            src=src[n..$];
            return true;
        }
        return false;
    }

    void skipLine() {
        while (!empty && front!='\n'&&src.length>0) {
            advance();
        }
    }

    void skipWhite(LexerFlags flags) {

        while(!empty && isWhite(front)) {
            if((!(flags&SKIP_EOL)) && (front=='\n')) return;
            advance();
        }
    }

    @property char front() {
        debug { 
            if (empty) writeln(RED, "error: using front on empty stream.", RESET);
        }
        return src[0];
    }     
    @property char next() {
        return src[1];
    }

    @property bool empty() {
        return src.length==0;
    }

    private bool handleOp(char first, string seconds, ref string token) {
        if (front==first) {
            foreach(c;seconds){
                if (next==c){
                    token=""~first~c;
                    advance(2);
                    return true;
                }
            }
            token=""~first;
            advance();
            return true;
        }
        return false;
    }

    private bool isAlphaNumOrUnderscore(char c) {
        return (c.isAlphaNum()||c=='_');
    }

    string src;
}

struct ShaderInput
{
    string name;
    string type;
}

void ParseShaderInputs(char[] src, ref ShaderInput[] attributes, ref ShaderInput[] uniforms) {
    string token;
    auto lexer = ShaderLexer(src.idup);
    while (lexer.tokenize(token)) {
        if (token=="uniform") {
            ShaderInput si;
            lexer.tokenize(si.type);
            lexer.tokenize(si.name);
            uniforms ~= si;
        } else if (token=="attribute") {
            ShaderInput si;
            lexer.tokenize(si.type);
            lexer.tokenize(si.name);
            attributes ~= si;
        }
    }
}

unittest {
    auto lexer1 = ShaderLexer("#version 120\nuniform float   hello_world;\n// the program\n\nvoid main(/*void*/){\nreturn;}\n\n");
    auto lexer2 = ShaderLexer("foo=(a.x+1)/i++;--bar");
    auto lexer3 = ShaderLexer("  gl_Position = Transfornation*vec4(in_Position, 1.0);");

    int i = 0;
    string token;
    while (lexer1.tokenize(token)) {
        assert(++i < 100);
        //writeln(token);
    }
    i = 0;    
    while (lexer2.tokenize(token)) {
        assert(++i < 100);
        //writeln(token);
    }
    i = 0;
    while (lexer3.tokenize(token)) {
        assert(++i < 100);
        //writeln(token);
    }
}
