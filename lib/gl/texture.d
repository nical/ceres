module gl.texture;

import gl.opengl;

struct Texture {

    this(GLenum aDimmension) {
        create();
        _dim    = aDimmension;
    }

    ~this() {
        destroy();
    }

    void setParameter(GLenum target, GLint param) {
        glTexParameteri(_dim,target,param);
    }
    void setParameter(GLenum target, GLfloat param) {
        glTexParameterf(_dim,target,param);
    }

    void setImage(GLint internalFormat, GLsizei w, GLsizei h
            , GLenum format, GLenum type
            , GLvoid* data
            , int dim = GL_TEXTURE_2D) {
        _dim = dim;
        _width  = w;
        _height = h;

        bind();
        glTexParameteri( _dim, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameteri( _dim, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexImage2D(_dim, 0, internalFormat, w, h, 0, format, type, data);
    }

    void create() {
        glGenTextures(1,&_id);
    }

    void destroy() {
        glDeleteTextures(1,&_id);
    }

    void bind() {
        glBindTexture(_dim, _id);
    }

    void unbind() {
        glBindTexture(_dim, 0);
    }

    

    static GLenum activeTextureIntToEnum(int i) pure {
        switch(i) {
            case 0:  return GL_TEXTURE0;
            case 1:  return GL_TEXTURE1;
            case 2:  return GL_TEXTURE2;
            case 3:  return GL_TEXTURE3;
            case 4:  return GL_TEXTURE4;
            case 5:  return GL_TEXTURE5;
            case 6:  return GL_TEXTURE6;
            case 7:  return GL_TEXTURE7;
            case 8:  return GL_TEXTURE8;
            default: return GL_TEXTURE0;//should throw instead
        }
    }

    @property 
    {
        GLint id() const pure {
        return _id;
        }

        GLsizei width() const pure {
            return _width;
        }
        GLsizei height() const pure {
            return _height;
        }

        uint dimmension() const pure {
            switch (_dim) {
                case GL_TEXTURE_1D : return 1;
                case GL_TEXTURE_2D : return 2;
                case GL_TEXTURE_3D : return 3;
                default : return 0;
            }
        }
        GLenum dimmensionEnum() const pure {
            return _dim;
        }

        GLenum isInitialized() const {
            return (dimmension!=0 && width!=0);
        }

        void activeTextureInt(int i) {
            _activeTexture = i;
        }

        void activeTextureEnum(GLenum e) {
            _activeTexture = activeTextureIntToEnum(e);
        }

        GLenum activeTextureEnum() const pure {
            return activeTextureIntToEnum(_activeTexture);  
        }
        GLenum activeTextureInt() const pure {
            return _activeTexture;  
        }
    }
private:
    GLenum  _dim = GL_TEXTURE_2D;
    GLuint  _id = 0;
    GLsizei _width = 0;
    GLsizei _height = 0;
    int  _activeTexture = 0;
}