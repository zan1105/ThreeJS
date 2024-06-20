// 异步加载 shader 文件
export default async function loadShader(path) {
	try {
		const src = await fetch(path);
		return await src.text();
	} catch (error) {
		console.error("shader 文件加载失败！", error);
		return null;
	}
}
