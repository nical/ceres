module ui.gl.shader;

import std.stdio;
import derelict.opengl.gl;
import gl3n.linalg;

import ui.gl.shaderlexer;
import ui.gl.utils;

enum { INVALID_SHADER_ID = 0xFFFFFF }

GLchar[] LoadtextFile(string path)
{
    writeln("load shader file");
    auto file = File(path,"r");
    GLchar[] src;
    GLchar[] line;
    while (file.readln(line)) {
        src ~= line;
    }
    write(src);

    writeln("..done");
    return src;    
}

Shader CreateShaderFromFile(string path, GLuint shaderType)
{
    assert(glGetError()==GL_NO_ERROR);
    GLchar[] src = LoadtextFile(path);
    Shader shader;
    shader.create(shaderType);
    shader.setSource(src);
    assert(shader.compile());
    assert(glGetError()==GL_NO_ERROR);
    return shader;
}

string getShaderErrorLog(GLuint shaderId)
{
    string errlog;
    //glGetShaderInfoLog( shaderId, GLsizei bufSize, GLsizei *length, char *infoLog )
    return errlog;
}

Program CreateProgarmFromFiles(string vsPath, string fsPath)
{
    assert(glGetError()==GL_NO_ERROR);

    auto vs = CreateShaderFromFile(vsPath, GL_VERTEX_SHADER);
    auto fs = CreateShaderFromFile(fsPath, GL_FRAGMENT_SHADER);

    Program p;
    p.create();
    p.attach(vs);
    p.attach(fs);
    p.link();
    p.setupUniforms(fs,vs);
    assert(glGetError()==GL_NO_ERROR);
    return p;
}

struct Shader
{
    void create(GLuint shaderType) {
        _type = shaderType;
        _id = glCreateShader(shaderType);
    }

    void destroy() {
        assert(isCreated);
        glDeleteShader(_id);
        _id = INVALID_SHADER_ID;
        _type = INVALID_SHADER_ID;
    }

    void setSource(GLchar[] src){
        assert(isCreated);
        GLchar* src0 = src.ptr;
        glShaderSource(_id, 1, &src0, null );
        _uniforms = FindUniforms(src);
        writeln("uniforms: ", _uniforms);
    }

    static string[] FindUniforms(GLchar[] src) {
        string[] uniforms;
        string token;
        auto lexer = ShaderLexer(src.idup);
        while (lexer.tokenize(token)) {
            if (token=="uniform") {
                lexer.tokenize(token);
                lexer.tokenize(token);
                uniforms ~= token;
            }
        }
        return uniforms;
    }

    bool compile() {
        assert(isCreated);
        debug{writeln("compiling shader ", _id);}
        glCompileShader(_id);

        GLchar[512] buf;
        GLint len;
        glGetShaderInfoLog(_id, buf.length, &len, &buf[0]);
        if (len>0) {
            writeln(buf[0..len]);
            return false;
        }
        return true;
    }

    @property isCreated() const pure { 
        return _id != INVALID_SHADER_ID; 
    }

    GLuint _id;
    GLuint _type; 
    string[] _uniforms;
}

struct Program
{
    void create() {
        _id = glCreateProgram();
    }

    void destroy() {
        glDeleteProgram(_id);
        _id = INVALID_SHADER_ID;
    }

    void bind() {
        glUseProgram(_id);
    }

    static void unbind() {
        glUseProgram(0);
    }

    void attach(ref Shader s) {
        glAttachShader(_id,s._id);
    }

    void link() {
        glLinkProgram(_id);
    }

    void setupUniforms(ref Shader vs, ref Shader fs) {
        foreach (u;vs._uniforms) {
            auto loc = glGetUniformLocation(_id, (u~"\0").ptr);
            _uniforms ~= ShaderLocation(ShaderLocation.UNIFORM,loc,u);
        }
        foreach (u;fs._uniforms) {
            bool found = false;
            foreach (l ; _uniforms) if (l._name==u) found=true;
            if (found) continue;
            auto loc = glGetUniformLocation(_id, (u~"\0").ptr);
            _uniforms ~= ShaderLocation(ShaderLocation.UNIFORM,loc,u);
        }
    }

    bool validate() {
        char[512] buffer=0;
        GLsizei len = 0;
        glGetProgramInfoLog(_id, buffer.length, &len, &buffer[0]);
        if (len>0) {
            writeln("Shader program ", _id," ", buffer[0..len/2]);
        } 
        GLint status;
        glGetProgramiv(_id, GL_VALIDATE_STATUS, &status);

        return (status != GL_FALSE);
    }

    inout(ShaderLocation)* uniform(size_t i) inout {
        return &_uniforms[i];
    }
    inout(ShaderLocation)* uniform(string name) inout {
        foreach(ref l; _uniforms) {
            if (l._name == name)
                return cast(inout(ShaderLocation)*) &l; 
        }
        return null;
    }
    inout(ShaderLocation)* opIndex(string name) inout {
        return uniform(name);
    }
    inout(ShaderLocation)* opIndex(GLint i) inout {
        return uniform(i);
    }

private:
    ShaderLocation[] _uniforms;
    ShaderLocation[] _attributes;
    
    GLuint _id = INVALID_SHADER_ID;
}

struct ShaderLocation {
    enum {
          FLOAT, FLOAT2, FLOAT3, FLOAT4
        , FLOAT2V, FLOAT3V, FLOAT4V
        , FLOAT16V
        , INT, INT2, INT3, INT4
        , INT2V, INT3V, INT4V
    }
    enum {UNIFORM, ATTRIBUTE};

    int _type;
    GLint _location;
    string _name;

    void set(float val) {
        glUniform1f(_location, val);
    }    
    void set(float a, float b) {
        glUniform2f(_location,a,b);
    }    
    void set(float a, float b, float c) {
        glUniform3f(_location,a,b,c);
    }
    void set(float a, float b, float c, float d) {
        glUniform4f(_location,a,b,c,d);
    }
    void set(GLint val) {
        glUniform1i(_location,val);
    }
    void set(GLint a, GLint b) {
        glUniform2i(_location,a,b);
    }
    void set(GLint a, GLint b, GLint c) {
        glUniform3i(_location,a,b,c);
    }
    void set(mat4 m) {
        glUniformMatrix4fv(_location, 1, GL_TRUE, m.value_ptr);
    }
}

//shader.location("color").uniform(r,g,b);
//shader["color"].set(r,g,b);
//shader.uniform("color").set(r,g,b);
//shader.uniform(2).set(r,g,b);
//shader.uniform("color", r,g,b);

