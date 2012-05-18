module ui.gl.texture;

import derelict.opengl.gl;

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

    void setImage(GLint internalFormat, GLsizei w, GLsizei h, GLenum format, GLenum type, GLvoid* data) {
        glTexImage2D(_dim, 0, internalFormat, w, h, 0, format, type, data);
        _width  = w;
        _height = h;
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
    }
private:
    GLenum  _dim;
    GLuint  _id;
    GLsizei _width;
    GLsizei _height;
}