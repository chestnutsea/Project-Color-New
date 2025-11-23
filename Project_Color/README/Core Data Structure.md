Core Data 结构
PhotoEntity
每张照片的主表，所有核心分析的入口。
属性名
类型
说明
id
UUID
唯一标识
assetLocalId
String
PHAsset 的标识符
timestamp
Date
拍摄时间
location
String?
地理信息
sceneLabel
String?
场景分类结果
thumbnail
Binary Data?
小图缓存
toneCategory
String
冷 / 暖 / 中性
styleLabel
String?
风格名称
features
🔁 Relationship → FeatureEntity (To Many)
一张照片可能有多个特征（FeaturePrint、CLIP 等）
styles
🔁 Relationship → StyleEntity (To Many)
🌟 支持多对多，一张照片多个风格
preference
🔗 Relationship → UserPreferenceEntity?
可选，用于建立偏好聚类反向关系
📎 关系说明
- 一张照片 → 多个 FeatureEntity（1:N）
- 一张照片 → 多个 StyleEntity（1:N）
- 一张照片 → 可属于一个用户偏好（N:1）
ColorSwatchEntity
如果不想用 Transformable 存 ColorSwatch 数组，则拆出表，便于后续对色彩做统计搜索。
属性名
类型
说明
id
UUID
唯一标识
hex
String
HEX 颜色值
l / a / b
Double
LAB 空间坐标
ratio
Double
占比（0~1）
photo
🔗 Relationship → PhotoEntity
所属照片
📎 通常 ColorSwatch 也可以不建实体，用 Transformable [ColorSwatch] 存在 PhotoEntity 里即可。
 不过建表可方便做 SQL 查询。
FeatureEntity
存放由 CoreML / Vision / CLIP 模型提取的向量特征。
属性名
类型
说明
id
UUID
唯一标识
modelSource
String
"FeaturePrint" / "CLIP" / "MobileNetV2" 等
vector
Binary Data
向量序列化结果（[Float32]）
dimension
Int16
向量维度
photo
🔗 Relationship → PhotoEntity
所属照片
📎 关系
- 多个 FeatureEntity 可对应同一张 PhotoEntity（N:1）。
StyleEntity
模型识别出的风格结果（可以多个标签）。
属性名
类型
说明
id
UUID
唯一标识
label
String
风格名称（如 "奶油风"、"复古"）
confidence
Double
置信度（0~1）
sourceModel
String
来源模型（CoreML/CLIP等）
photos
🔗 Relationship → PhotoEntity (To Many)
反向关系：styles，支持多对多
📎 关系
- 多个 StyleEntity 对应同多张 PhotoEntity（N:N）。
UserPreferenceEntity
用户聚类偏好画像结果，系统汇总得出。
属性名
类型
说明
id
UUID
唯一标识
dominantTone
String
主偏好色调（冷/暖/中）
avgSaturation
Double
平均饱和度
avgLightness
Double
中位明度
embeddingCenter
Binary Data
📜 向量（聚类中心）
styleDistribution
📜 Transformable [String: Double]
各风格出现比例（如 {"复古":0.3, "奶油":0.2}）
lastUpdated
Date
更新时间
photos
🔁 Relationship → PhotoEntity
多张照片属于该偏好（1:N）
📎 关系
- 一个偏好聚类 → 多张照片（1:N）。
总览
实体
关系
列表属性
PhotoEntity
1:N → FeatureEntity、1:N → StyleEntity、N:1 → UserPreferenceEntity
dominantColors [ColorSwatch]
FeatureEntity
N:1 → PhotoEntity
vector [Float]
StyleEntity
N:1 → PhotoEntity
无
UserPreferenceEntity
1:N → PhotoEntity
styleDistribution [String:Double]、embeddingCenter [Float]
ColorSwatchEntity (可选)
N:1 → PhotoEntity
无
