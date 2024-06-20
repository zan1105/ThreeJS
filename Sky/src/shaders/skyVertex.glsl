// 太阳
uniform float Intensity;// 亮度
uniform vec3 sunPosition;// 太阳位置

// 天空
uniform float skyscale;
uniform float rayleigh;// 瑞利散射
uniform vec3 up;// 相机上方

varying vec3 vWorldPosition;// 世界坐标
varying vec3 vSunDirection;// 阳光方向
varying float vSunfade;// 太阳照射范围
varying vec3 vBetaR;// 瑞利系数
varying float vSunE;// 阳光强度

// 相关常数
const float e = 2.71828182845904523536028747135266249775724709369995957;
const float pi = 3.141592653589793238462643383279502884197169;
const vec3 totalRayleigh = vec3( 5.804542996261093E-6, 1.3562911419845635E-5, 3.0265902468824876E-5 );// RGB瑞利散射
const float cutoffAngle = 1.6110731556870734;
const float steepness = 1.5;
const float EE = 1000.0;

float sunIntensity( float zenithAngleCos ) {
    zenithAngleCos = clamp( zenithAngleCos, -1.0, 1.0 );
    return Intensity * EE * max( 0.0, 1.0 - pow( e, -( ( cutoffAngle - acos( zenithAngleCos ) ) / steepness ) ) );
}

void main() {
    vec4 worldPosition = skyscale*modelMatrix * vec4( position, 1.0 );
    vWorldPosition = skyscale*worldPosition.xyz;

    gl_Position = skyscale*projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
    gl_Position.z = gl_Position.w; // set z to camera.far

    vSunDirection = normalize( sunPosition );// 归一化
    float sun_up = dot( vSunDirection, up );

    vSunE = sunIntensity( sun_up );
    vSunfade = 1.0 - clamp( 1.0 - exp( ( sun_up ) ), 0.0, 1.0 );// 太阳照射范围

    float rayleighCoefficient = rayleigh - ( 1.0 * ( 1.0 - vSunfade ) );
    vBetaR = totalRayleigh * rayleighCoefficient;// 瑞利系数
}