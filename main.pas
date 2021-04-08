{ -*- mode: opascal; opascal-indent-level: 4 -*- }
program main;

{$H+}

uses
    GL, GLEXT, GLUT, Math;

const
    CIRCLE_VERTEX_COUNT = 10;
    SCREEN_WIDTH = 800;
    SCREEN_HEIGHT = 600;

procedure DisplayWindow; cdecl;
begin
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glutSwapBuffers;
end;

function CompileShaderSource(ShaderType: GLenum; ShaderSource: PChar; var Shader: GLuint): Boolean;
const
    INFO_LOG_CAPACITY = 1024;
var
    Compiled : GLint;
    InfoLog : array[0 .. INFO_LOG_CAPACITY - 1] of GLchar;
    InfoLogLength : GLsizei;
begin
    Shader := glCreateShader(ShaderType);
    glShaderSource(Shader, 1, @ShaderSource, nil);
    glCompileShader(Shader);
    glGetShaderiv(Shader, GL_COMPILE_STATUS, @Compiled);

    if not Boolean(Compiled) then
    begin
        glGetShaderInfoLog(Shader, INFO_LOG_CAPACITY, @InfoLogLength, @InfoLog);
        WriteLn(InfoLog);
    end;

    CompileShaderSource := Boolean(Compiled);
end;

function LinkShaderProgram(Shaders: array of GLuint; var ShaderProgram: GLuint): Boolean;
const
    INFO_LOG_CAPACITY = 1024;
var
    i : Integer;
    Linked: GLint;
    InfoLog : array[0 .. INFO_LOG_CAPACITY - 1] of GLchar;
    InfoLogLength : GLsizei;
begin
    ShaderProgram := glCreateProgram();
    for i := Low(Shaders) to High(Shaders) do
        glAttachShader(ShaderProgram, Shaders[i]);
    glLinkProgram(ShaderProgram);
    glGetProgramiv(ShaderProgram, GL_LINK_STATUS, @Linked);

    if not Boolean(Linked) then
    begin
        glGetProgramInfoLog(ShaderProgram, INFO_LOG_CAPACITY, @InfoLogLength, @InfoLog);
        WriteLn(InfoLog);        
    end;

    LinkShaderProgram := Boolean(Linked);
end;

var
    Time: GLfloat = 0;
    UniformTime: GLint;
    UniformResolution: GLint;

procedure OnTimer(value: LongInt); cdecl;
begin
  glutPostRedisplay;
  Time := Time + 0.020;
  glUniform1f(UniformTime, Time);
  glutTimerFunc(20, @OnTimer, 0);
end;

var
    VertexShaderSource : PChar =
        '#version 300 es'#10 +
        'precision mediump float;'#10 +
        'uniform int vertex_count;'#10 +
        'uniform vec2 resolution;'#10 +
        ''#10 +
        'out vec2 uv;'#10 +
        ''#10 +
        'void main() {'#10 +
        '    float aspect = resolution.y / resolution.x;'#10 +
        '    float x = float(gl_VertexID & 1);'#10 +
        '    float y = float((gl_VertexID >> 1) & 1);'#10 +
        '    gl_Position = vec4(x * aspect - 0.5, y - 0.5, 0.0, 1.0);'#10 +
        '    uv = vec2(x, y);'#10 +
        '}'#10 +
            '';
    FragmentShaderSource : PChar =
        '#version 300 es'#10 +
        'precision mediump float;'#10 +
        ''#10 +
        'uniform float time;'#10 +
        ''#10 +
        'in vec2 uv;'#10 +
        'out vec4 output_color;'#10 +
        ''#10 +
        'void main() {'#10 +
        '    float radius = (sin(time) + 1.0) / 4.0;'#10 +
        '    float r = (sin(uv.x + time) + 1.0) / 2.0;'#10 +
        '    float g = (cos(uv.y + time) + 1.0) / 2.0;'#10 +
        '    float b = (cos(uv.x + time + 0.5) + 1.0) / 2.0;'#10 +
        '    float d = length(uv - vec2(0.5, 0.5));'#10 +
        '    output_color = d <= radius ? vec4(r, g, b, 1.0) : vec4(0.0);'#10 +
        '}'#10 +
            '';
    Shaders: array [0..1] of GLuint;
    ShaderProgram: GLuint;
    UniformVertexCount: GLint;

procedure OnReshape(WindowWidth, WindowHeight: LongInt); cdecl;
var
    ViewWidth : Single;
    ViewHeight : Single;
begin
    ViewWidth := Single(WindowWidth);
    ViewHeight := Single(WindowWidth) * (Single(SCREEN_HEIGHT) / Single(SCREEN_WIDTH));

    if (ViewHeight > WindowHeight) then
    begin
        ViewHeight := WindowHeight;
        ViewWidth := WindowHeight * (Single(SCREEN_WIDTH) / Single(SCREEN_HEIGHT));
    end;

    glViewport(
        Floor(Single(WindowWidth) * 0.5 - ViewWidth * 0.5),
        Floor(Single(WindowHeight) * 0.5 - ViewHeight * 0.5),
        Floor(ViewWidth),
        Floor(ViewHeight));

    glUniform2f(UniformResolution, Single(SCREEN_WIDTH), Single(SCREEN_HEIGHT));
end;

begin
    glutInit(@argc, argv);
    glutInitDisplayMode(GLUT_RGB or GLUT_DOUBLE or GLUT_DEPTH);
    glutInitWindowSize(SCREEN_WIDTH, SCREEN_HEIGHT);
    glutCreateWindow('Pascalik');
    glutDisplayFunc(@DisplayWindow);
    glutTimerFunc(20, @OnTimer, 0);
    glutReshapeFunc(@OnReshape);

    Load_GL_VERSION_3_0();

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    WriteLn;
    WriteLn('GL info:');
    WriteLn('  Vendor: ', glGetString(GL_VENDOR));
    WriteLn('  Renderer: ', glGetString(GL_RENDERER));
    WriteLn('  Version: ', glGetString(GL_VERSION));
    // WriteLn('  Extensions: ', glGetString(GL_EXTENSIONS));

    if CompileShaderSource(GL_VERTEX_SHADER, VertexShaderSource, Shaders[0]) then
        WriteLn('Successfully compiled vertex shader')
    else
        WriteLn('ERROR: Failed to compile vertex shader');

    if CompileShaderSource(GL_FRAGMENT_SHADER, FragmentShaderSource, Shaders[1]) then
        WriteLn('Successfully compiled fragment shader')
    else
        WriteLn('ERROR: Failed to compile fragment shader');

    if LinkShaderProgram(Shaders, ShaderProgram) then
        WriteLn('Successfully linked the shader program')
    else
        WriteLn('ERROR: Failed to link the shader program');

    UniformVertexCount := glGetUniformLocation(ShaderProgram, 'vertex_count');
    UniformTime := glGetUniformLocation(ShaderProgram, 'time');
    UniformResolution := glGetUniformLocation(ShaderProgram, 'resolution');

    glUniform1i(UniformVertexCount, CIRCLE_VERTEX_COUNT);
    glUniform1f(UniformTime, Time);
    glUniform2f(UniformResolution, Single(SCREEN_WIDTH), Single(SCREEN_HEIGHT));

    glUseProgram(ShaderProgram);

    glutMainLoop;
end.
