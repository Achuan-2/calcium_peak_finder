具备功能

- 自动识别钙信号的峰值
- 快速查看每个神经元的识别效果
- 自动统计

  - spike 数目
  - spike 峰值
  - 钙响应时间的长度(计算FHWM）
  - 钙事件频率
  - 钙事件发放间隔
- 手动增删peak

输入数据格式

- 可以是mat和excel，如果mat有多个变量或者excel有多个表，load之后软件会询问应该导入哪个数据。
- 数据的格式为二维矩阵，行为神经元，列为帧

Github 地址：[Achuan-2/calcium_peak_finder](https://github.com/Achuan-2/calcium_peak_finder)