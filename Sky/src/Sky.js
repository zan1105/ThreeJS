import {
	Mesh,
	ShaderMaterial,
	UniformsUtils,
	SphereGeometry,
	BackSide,
	LinearFilter,
	ACESFilmicToneMapping,
	Vector3,
	Color,
	TextureLoader,
	RepeatWrapping,
} from '../../Three/three.module.min.js';

class Sky extends Mesh {
	constructor(options={}) {
		const shader = Sky.Shader;
		const material = new ShaderMaterial({
			name: 'SkyShader',
			fragmentShader: shader.fragmentShader,
			vertexShader: shader.vertexShader,
			uniforms: UniformsUtils.clone(shader.uniforms),
			side: BackSide,
			depthWrite: false
		});

		const url = options.url || '../img/perlin256.png';
		const texture = new TextureLoader().load(url);
		texture.anisotropy = 16;
		texture.wrapS = RepeatWrapping;
		texture.wrapT = RepeatWrapping;
		texture.flipY = false;
		texture.minFilter = LinearFilter;
		texture.magFilter = LinearFilter;
		texture.generateMipmaps = false;

		material.uniforms['map'].value = texture;

		super(new SphereGeometry(1, 32, 16), material);
		// super(new CubeGeometry(1, 1, 1), material);

		this.isSky = true;
	}
}

const uniforms = {
	// 太阳
	'sun_color':{value:new Color(1.0,0.0,0.0)},// 太阳颜色
	'sunAngularDiameter':{value:0.505},//太阳角半径
    'Intensity': { value: 1. },//sun亮度
	'sunPosition': { value: new Vector3() },//太阳位置
	'mieDirectionalG': { value: 1. },//米氏方向因子（阳光高光范围，值越大范围越小，亮度越高）
	'Exposure': { value: 1.0 },// 曝光度

	// 天空
	'skyscale': { value: 1.0 },// 天空缩放
	'turbidity': { value: 10. },//浊度
	'skylineF': { value: 0.2 },// 云天际线因子
	'rayleigh': { value: .4 },//瑞利散射系数
	'mieCoefficient': { value: 0.005 },//米氏系数
	'skyGlowColor':{value:new Color(1.0,0.5,0.5)},// 天空霞光颜色
	'sunGlowColor':{value:new Color(0.9216,0.2431,0.1059)},// 太阳霞光颜色
	'backSkyColor':{value:new Color(0.1,0.1,0.1)},// 背面天空颜色
	'up': { value: new Vector3(0., 1., 0.) },//上方向量

	// 云朵
	'map': { value: null },// 云噪声图
	'uTime': { value: 1.0 },// 运行时间
	'weaken': { value: 0.15 },// 采样衰减因子
	'THICKNESS': { value: 0.001 },// 云厚度
	'N_LIGHT_STEPS': { value: 3 },// 光照计算迭代次数
	'curve': { value: 0.3 },// 坐标曲率
	'speed': { value: 0.5 },// 风速
	'wind':{value:new Vector3(0.3,0.1,0.3)},// 风向
	'coverage': { value: 0.5 },// 覆盖率`
	'ABSORPTION': { value: 0.45 },// 云的光线吸收率
	'mult': { value: 0.2 },// 位置变换系数，控制局部变化翻滚
	'N_MARCH_STEPS': { value: 12 },// 云采样迭代次数

	// 雾
	'fogColor': { value: new Color(0.7,0.7,0.7) },// 雾颜色
	'fogDensity': { value: 0.0001 },// 雾密度
};

Sky.Shader = {
	uniforms: uniforms,
	vertexShader: ``,
	fragmentShader: ``,
}

export default Sky;
