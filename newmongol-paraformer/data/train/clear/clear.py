import json

# 定义输入和输出文件路径
input_file = "audio_datasets.jsonl"
output_file = "clear_audio_datasets.jsonl"

# 打开输入文件进行读取
with open(input_file, "r", encoding="utf-8") as infile, open(output_file, "w", encoding="utf-8") as outfile:
    # 逐行读取并处理
    for line in infile:
        try:
            # 将每一行的JSON字符串转为字典
            data = json.loads(line)

            # 检查是否存在 'target' 字段
            if "target" in data:
                # 如果存在 'target' 字段，将这行写入新的文件
                outfile.write(line)

        except json.JSONDecodeError:
            print(f"无法解析的行: {line}")