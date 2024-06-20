precision highp float;
precision highp int;
precision highp sampler2D;


// 太阳
uniform vec3 sun_color;// 太阳颜色
uniform float sunAngularDiameter;// 太阳角直径,默认为0.505度
uniform float mieDirectionalG;// 米式散射因子-方向光高光
uniform float Exposure;// 色调映射曝光

// 天空
uniform float skyscale;
uniform float turbidity;// 浑浊度
uniform float skylineF;// 天际线
uniform float rayleigh;// 瑞利散射
uniform float mieCoefficient;// 米氏因子（白）
uniform vec3 skyGlowColor;// 天空霞光颜色
uniform vec3 sunGlowColor;// 太阳霞光颜色
uniform vec3 backSkyColor;// 背面天空颜色
uniform vec3 up;// 相机上方

// 云朵
uniform sampler2D map;// 云噪声图
uniform float uTime;// 时间
uniform float weaken;// 采样衰减因子
uniform float THICKNESS;// 云厚度
uniform int N_LIGHT_STEPS;// 光照计算迭代次数
uniform float curve;// 坐标高度曲率
uniform float speed;// 风速
uniform vec3 wind;// 风向
uniform float coverage;// 覆盖率
uniform float ABSORPTION;// 云的光线吸收率
uniform float mult;//位置变换系数，控制局部变化翻滚
uniform int N_MARCH_STEPS;// 云厚度迭代次数

// 雾
uniform float fogDensity;// 雾密度
uniform vec3 fogColor;// 雾颜色

varying vec3 vWorldPosition;// 当前片元的坐标（已转换）
varying vec3 vSunDirection;// 太阳方向
varying float vSunfade;// 边缘褪色-影响阳光范围
varying vec3 vBetaR;// 瑞利散射
varying float vSunE;// 光强

// 云--------------------------------------------------------------------------
const vec3 cameraPos = vec3( 0.0, 0.0, 0.0 );// 相机位置
const float pi = 3.141592653589793238462643383279502884197169;
const float TWO_PI = 6.28318530717958648;

// 生成3D噪声
float noise3D(vec3 p){return texture(map, p.xz).x;}// 采集噪声值

// 3*3采样位置变换矩阵
const mat3 m = mat3(0.00, 0.80, 0.60, -0.80, 0.36, -0.48, -0.60, -0.48, 0.64);

// 计算叠加噪声值（模拟分形布朗克运动）
float fbm(vec3 p)
{
    float t=0.;
    float a=pow(weaken,0.01);// 初始系数

    for (int i=0; i<6; i++){
        t += a * noise3D(p);
        p = m * p * mult;
        a *= weaken;
    }

    return t;
}

// 云密度（返回 pos 位置的云密度值）cov为密度阈值参数
float cloud_density(vec3 pos, float cov)
{
    float dens = fbm(pos);// 修改
    return smoothstep(cov, 1., dens);// 阈值缩放
}

// 云亮度计算
float cloud_light(vec3 pos, vec3 sundir_step, float cov)
{
    float T = 1.0;// 透明度，transmitance
    float dens;// 密度
    float T_i;// 透射率
    
    for(int i = 0;i<N_LIGHT_STEPS; i++ )
    {
        dens = cloud_density(pos, cov);
        T_i = exp(-ABSORPTION * dens);
        T *= T_i;
        pos += sundir_step;
    }
    T =  clamp(T, 0., 1.);
    return T;
}

// 云渲染（根据天空（云）坐标和视角方向计算当前方向的云颜色值和透明度）
vec4 render_clouds(vec3 rayOrigin, vec3 rayDirection)
{
    float march_step = (THICKNESS+.0002)/float(N_MARCH_STEPS);// 云迭代步长
    vec3 pos = rayOrigin +speed* vec3(uTime * wind.x, uTime*wind.y, uTime * wind.z);// 云初始位置
    vec3 dir_step = rayDirection * march_step;// 计算云迭代方向步长

    vec3 light_step = normalize(vSunDirection-cameraPos)*march_step;// 光线迭代步长
    
    float T = 1.0;// 云初始透明度
    vec3 C = vec3(0.0);// 云初始颜色
    float alpha = 0.0;// 初始不透明度
    float dens;// 密度
    float T_i;// 透射率
    float cloudLight;// 云透光率
    
    for(int i = 0; i<N_MARCH_STEPS; i++ )
    {
        dens = cloud_density(pos, 1.-coverage);// 密度
        
        T_i = exp(-ABSORPTION * dens * march_step);// 累积系数
        T *= T_i;// 累积透明度
        cloudLight = cloud_light(pos, light_step, 1.-coverage);// 云透光率（实现太阳照到云的高亮）
        C += T * cloudLight * dens * march_step;//累加片元颜色
        C = mix(C * 0.9, C, clamp(cloudLight, 0.0, 1.0));//颜色混合（阴影）
        alpha += (1.0-T_i) * (1.0-alpha);// 片元颜色透明度
        if (alpha > .99) break;// 透明度接近1，提前退出循环节省性能开销
        pos += dir_step;
    }
    
    return vec4(C, alpha);
}

// 天空----------------------------------------------------------------------------------------
const float rayleighZenithLength = 8.4E3;// 瑞利光程
const float mieZenithLength = 1.25E3;// 米氏光程
const float THREE_OVER_SIXTEENPI = 0.05968310365946075;// 3.0 / ( 16.0 * pi )
const float ONE_OVER_FOURPI = 0.07957747154594767;// 1.0 / ( 4.0 * pi )
const vec3 MieConst = vec3( 1.8399918514433978E14, 2.7798023919660528E14, 4.0790479543861094E14 );// RGB米氏散射值

// 瑞利散射相位因子
float rayleighPhase( float cosTheta ) {return THREE_OVER_SIXTEENPI * ( 1.0 + pow( cosTheta, 2.0 ) );}

// 米氏散射相位因子
float hgPhase( float cosTheta, float g ) {
    float g2 = pow( g, 2.0 );
    float inverse = 1.0 / pow( 1.0 - 2.0 * g * cosTheta + g2, 1.5 );
    return ONE_OVER_FOURPI * ( ( 1.0 - g2 )  * inverse );
}

// 米氏散射计算
vec3 totalMie( float T ) {
    float c = ( 0.2 * T ) * 10E-18;
    return 0.434 * c * MieConst;
}

// 色彩逆映射
vec3 ReRRTAndODTFit( vec3 color ) {
    vec3 ret;
    ret = -(sqrt(10.0)*sqrt((-187345541948750.0*pow(color,vec3(2.0)))+232671271403227.0*color+241563894490.0)+21647550.0*color-1228930.0)/(98372900.0*color-100000000.0);
    return ret;
}

// 色调逆映射
vec3 ReACESToneMapping( vec3 color ) {
    mat3 InputM_I = mat3(1.76474, -0.14703, -0.03634, 
                        -0.67578, 1.16025, -0.16244,
                        -0.08896, -0.01322, 1.19877);
    mat3 Output_I = mat3(0.64304, 0.05927, 0.005962,
                        0.31119, 0.93144, 0.06393,
                        0.04578, 0.00929, 0.93012);
    
    vec3 ret;
    ret = InputM_I * ReRRTAndODTFit(Output_I * color)* 0.6 / Exposure;
    return ret;
}

void main() {
    vec3 direction = normalize( vWorldPosition - cameraPos );
    float view = smoothstep( 0.0, 1.0, dot( up, direction ) );// 0~1
    float zenithAngle = acos( max( 0.0, dot( up, direction ) ) );
    float inverse = 1.0 / ( cos( zenithAngle ) + 0.15 * pow( 93.885 - ( ( zenithAngle * 180.0 ) / pi ), -1.253 ) );
    float sR = rayleighZenithLength * inverse;// 瑞利天顶长度
    float sM = mieZenithLength * inverse;// 米式天顶长度
    float sun_up = smoothstep(0., 1., dot( up, vSunDirection ));

    // 云
    vec3 pos = normalize( vWorldPosition);//将立方体坐标转换为网格球体    
    vec4 cld = vec4(1., 1., 1., 1.);
    float d_factor = 1. - smoothstep(0., skylineF, pos.y);// 天际线距离因子,近小远大
    if (pos.y>0.)// 只计算地平线(0.)以上的云
    {
        float df = 1. / (curve*pos.y + .1);// 坐标距离因子,近小远大
        vec3 posS = .4*df*pos;// 云(天空)坐标

        vec3 raydir = normalize(posS - cameraPos);// 云(天空)方向
        cld = render_clouds(posS, raydir);
    }
        
    // 米氏系数mie coefficients		
    vec3 vBetaM = totalMie( turbidity )*mieCoefficient;// 天空米式系数

    // 联合消光（散射）因子combined extinction factor
    vec3 Fex = exp( -( vBetaR * sR + vBetaM * sM ) );// 天空
    vec3 Fex_c = exp( -( vBetaR * sR  + vBetaM * sM * (10000. * cld.a + 1.))/2. );// 云

    float cosTheta = dot( direction, vSunDirection );//片元方向和太阳方向的夹角余弦

    // 太阳
    float sunAngularDiameterCos = cos( sunAngularDiameter * pi / 180. );// 太阳角直径余弦
    float sundisk = smoothstep( sunAngularDiameterCos, 1., cosTheta );// 太阳圆盘
    vec3 suncolor = vSunE * 19000. * Fex * sundisk;// 圆盘颜色
    suncolor *= 1. - smoothstep(0., 1., cld.a*2000.);// 云遮挡

    // 瑞利散射
    float rPhase = rayleighPhase( cosTheta * 0.5 + 0.5 );//瑞利相位,取值:0.736~1.178
    vec3 betaRTheta = vBetaR * rPhase;// 天空的瑞利散射
    vec3 cloudBetaR = vBetaR * rPhase;// 云的瑞利散射

    // 米氏散射
    float a = 1. - smoothstep(0., 1., cld.a*2000.);// 单散射的反射率
    float mPhase = a*hgPhase( cosTheta, mieDirectionalG );
    vec3 betaMTheta = vBetaM * mPhase;

    // 天空颜色
    vec3 Lin = pow( vSunE * ( ( betaRTheta + betaMTheta ) / ( vBetaR + vBetaM ) ) * ( 1.0 - Fex ), vec3( 3.5 ) );//天空颜色蓝度1.5
    Lin *= mix( vec3( 1.0 ), pow( vSunE * ( ( betaRTheta + betaMTheta ) / ( vBetaR + vBetaM ) ) * Fex, vec3( 1.0 / 2.0 ) ), clamp( pow( 1.0 - dot( up, vSunDirection ), 5. ), 0.0, 1.0 ) );
    
    vec3 L0 = vec3( 0.1 ) * Fex;// 天空底色（夜空）

    // 云颜色
    vec3 cloud = pow( vSunE * ( ( cloudBetaR + betaMTheta ) / ( vBetaR + vBetaM ) ) * ( 1.0 - Fex_c ), vec3( 1.5 ) );//天空颜色蓝度1.5
    cloud *= mix( vec3( 1.0 ), pow( vSunE * ( ( cloudBetaR + betaMTheta ) / ( vBetaR + vBetaM ) ) * Fex_c, vec3( 1.0 / 2.0 ) ), clamp( pow( 1.0 - dot( up, vSunDirection ), 5. ), 0.0, 1.0 ) );
    cloud *= 1. + cld.xyz*2000.;// 云阴影

    // 早晚霞
    vec3 delta2 = pow(pos.xyz-vSunDirection.xyz, vec3(2.));
    vec2 glowRange = vec2(4., 0.5);
    vec2 R = vec2(delta2.x+delta2.z, delta2.y) / glowRange;
    float deltaR = R.x+R.y;// 晚霞范围（椭圆）
    float f = 1.-smoothstep(0., 0.26, sun_up);
    vec3 cloudGlow = ReACESToneMapping(skyGlowColor);
    cloud = mix(cloud, cloudGlow, f);// 基础红霞
    if (pos.y>0. && deltaR < 1.){
        vec3 sunFixColor = ReACESToneMapping(sunGlowColor);
        cloud = mix(cloud, sunFixColor, f*(1.-deltaR));
    }

    vec3 bluecolor = vec3( 0.0002, 0.00045, 0.0008 );// 蓝天修正偏移色

    vec3 texColor = ( Lin + L0 ) * 0.04 + bluecolor;// Lin为蓝色天空，L0为夜空底色；
    vec3 retColor = pow( texColor, vec3( 1.0 / ( 1.2 + ( 1.2 * vSunfade ) ) ) );

    cloud = mix(cloud, retColor, clamp(d_factor, 0., 1.));//云天际线颜色
    retColor = mix(retColor+suncolor, cloud, clamp((cld.a)*2000.,0.,1.));// 混合云和天空颜色

    vec3 backcolor = ReACESToneMapping(backSkyColor);// 背景色色调映射
    // vec3 backcolor = ReACESToneMapping(sRGBToLinear(vec4(backSkyColor,1.0)).rgb);// 背景色色调映射

    // backcolor = sRGBToLinear(vec4(backcolor,1.0)).rgb;// 转换为线性空间
    if (pos.y < 0.){retColor = mix(backcolor, retColor, pow(1.+pos.y, 30.));}// 地面阴影
    vec3 fog_Color = ReACESToneMapping(fogColor);
    retColor = mix(retColor, fog_Color, fogDensity);// 雾效果
    retColor = clamp(retColor, 0., 14.);// 颜色范围

    gl_FragColor = vec4(retColor, 1.0);// 输出片元颜色
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}