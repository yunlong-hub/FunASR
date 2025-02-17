这个分词脚本的使用方法如下：

使用方法

	1.	命令行参数概述：
脚本使用命令行参数来配置不同的功能。以下是可用参数及其说明：

usage: script.py [-h] [--log_level {CRITICAL,ERROR,WARNING,INFO,DEBUG,NOTSET}]
                 --input INPUT --output OUTPUT
                 [--field FIELD] [--token_type {char,bpe,word,phn}]
                 [--delimiter DELIMITER] [--space_symbol SPACE_SYMBOL]
                 [--bpemodel BPEMODEL]
                 [--non_linguistic_symbols NON_LINGUISTIC_SYMBOLS]
                 [--remove_non_linguistic_symbols REMOVE_NON_LINGUISTIC_SYMBOLS]
                 [--cleaner {None,tacotron,jaconv,vietnamese,korean_cleaner}]
                 [--g2p {g2p_classes}] [--write_vocabulary WRITE_VOCABULARY]
                 [--vocabulary_size VOCABULARY_SIZE] [--cutoff CUTOFF]
                 [--add_symbol ADD_SYMBOL]


	2.	必需参数：
	•	--input, -i：输入文本文件的路径。使用 - 表示从标准输入读取。
	•	--output, -o：输出文本文件的路径。使用 - 表示输出到标准输出。
	3.	可选参数：
	•	--field, -f：要提取的输入文本列（1 基数整数），例如 2- 表示提取第二列到最后一列。
	•	--token_type, -t：选择分词类型，可以是 char（字符级）、bpe（字节对编码）、word（词级）或 phn（音素）。
	•	--delimiter, -d：输入文本的分隔符。
	•	--space_symbol：指定空格符号，默认值为 <space>。
	•	--bpemodel：BPE 模型文件的路径（仅在 token_type 为 bpe 时有效）。
	•	--non_linguistic_symbols：非语言符号文件的路径。
	•	--remove_non_linguistic_symbols：是否从标记中移除非语言符号，默认值为 False。
	•	--cleaner：文本清理类型，支持 None, tacotron, jaconv, vietnamese, korean_cleaner。
	•	--g2p：指定 G2P 方法（如果 token_type 为 phn）。
	•	--write_vocabulary：是否生成词汇表，默认值为 False。
	•	--vocabulary_size：词汇表大小，默认为 0（不限制）。
	•	--cutoff：写入词汇表模式时使用的截止频率，默认为 0。
	•	--add_symbol：添加额外的符号，例如 --add_symbol '<blank>:0'。
	4.	示例命令：
	•	从输入文件 input.txt 中读取文本，使用字符级分词，输出结果到 output.txt：

python script.py --input input.txt --output output.txt --token_type char


	•	从标准输入读取数据，提取第二列，以空格作为分隔符，输出到标准输出：

cat input.txt | python script.py --input - --output - --field 2 --delimiter " "


	•	生成词汇表，限制词汇表大小为 5000，使用截止频率为 5：

python script.py --input input.txt --output vocab.txt --write_vocabulary True --vocabulary_size 5000 --cutoff 5



注意事项

	•	确保在命令行中使用适当的参数格式。
	•	使用 -h 或 --help 参数可以查看完整的帮助信息：

python script.py -h



通过上述方法，你可以灵活地使用这个脚本进行文本分词和词汇表生成。