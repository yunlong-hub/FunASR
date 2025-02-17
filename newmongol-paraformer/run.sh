#!/usr/bin/env bash


CUDA_VISIBLE_DEVICES="0"

# general configuration
feats_dir="../data" #feature output dictionary
exp_dir=`pwd`
lang=mn  #语种
token_type=bpe # token类型
stage=2
stop_stage=2

# feature configuration
nj=32


# 推理的设置
inference_device="cuda" #"cpu"
inference_checkpoint="model.pt.avg10"
inference_scp="wav.scp"
inference_batch_size=32

# data
# raw_data=../raw_data
# data_url=www.openslr.org/resources/33

# exp tag
tag="exp1"
workspace=`pwd`

master_port=12345

. utils/parse_options.sh || exit 1;

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

train_set=train
valid_set=test
test_sets="test"

config=config.yaml
model_dir="baseline_$(basename "${config}" .yaml)_${lang}_${token_type}_${tag}"


# if [ ${stage} -le -1 ] && [ ${stop_stage} -ge -1 ]; then
#     echo "stage -1: Data Download"
#     mkdir -p ${raw_data}
#     local/download_and_untar.sh ${raw_data} ${data_url} data_aishell
#     local/download_and_untar.sh ${raw_data} ${data_url} resource_aishell
# fi

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "stage 0: Data preparation"
    # Data preparation
    # local/aishell_data_prep.sh ${raw_data}/data_aishell/wav ${raw_data}/data_aishell/transcript ${feats_dir}
    for x in train; do

        # convert wav.scp text to jsonl
        scp_file_list_arg="++scp_file_list='[\"data/${x}/wav.scp\",\"data/${x}/text\"]'"
        python ../funasr/datasets/audio_datasets/scp2jsonl.py \
        ++data_type_list='["source", "target"]' \
        ++jsonl_file_out=data/${x}/audio_datasets.jsonl \
        ${scp_file_list_arg}

    done
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "stage 1: Feature and CMVN Generation"
    python ../funasr/bin/compute_audio_cmvn.py \
    --config-path "${workspace}/conf" \
    --config-name "${config}" \
    ++train_data_set_list="data/${train_set}/audio_datasets.jsonl" \
    ++cmvn_file="data/${train_set}/cmvn.json"

fi

token_list=data/${lang}_token_list/$token_type/tokens.txt
echo "dictionary: ${token_list}"
if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: Dictionary Preparation"
    mkdir -p data/${lang}_token_list/$token_type/   
    # echo "make a dictionary"
    # echo "<blank>" > ${token_list}
    # echo "<s>" >> ${token_list}
    # echo "</s>" >> ${token_list}
    # echo "<unk>" >> ${token_list}

    /data/yunlong/FunASR/funasr/bin/tokenize_text.py --input data/train/text \
    --output data/mn_token_list/bpe/tokens.txt --field 2- \
    --token_type bpe --bpemodel data/mn_token_list/bpe/train_bpe10000.model  --write_vocabulary True --vocabulary_size 10000
fi

# if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
#     echo "stage 2: Dictionary Preparation"
#     mkdir -p data/${lang}_token_list/$token_type/
#     echo "make a dictionary"
#     echo "<blank>" > ${token_list}
#     echo "<s>" >> ${token_list}
#     echo "</s>" >> ${token_list}
#     utils/text2token.py -s 1 -n 1 --space "" data/$train_set/text | cut -f 2- -d" " | tr " " "\n" \
#         | sort | uniq | grep -a -v -e '^\s*$' | awk '{print $0}' >> ${token_list}
#     echo "<unk>" >> ${token_list}
# fi

# LM Training Stage
if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: LM Training"
fi

# ASR Training Stage
if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
  echo "stage 4: ASR Training"

  mkdir -p ${exp_dir}/exp/${model_dir}
  current_time=$(date "+%Y-%m-%d_%H-%M")
  log_file="${exp_dir}/exp/${model_dir}/train.log.txt.${current_time}"
  echo "log_file: ${log_file}"
  export CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES
  gpu_num=$(echo $CUDA_VISIBLE_DEVICES | awk -F "," '{print NF}')
  echo ${gpu_num}
  torchrun \
  --nnodes 1 \
  --nproc_per_node ${gpu_num} \
  --master_port ${master_port} \
  ../funasr/bin/train.py \
  --config-path "${workspace}/conf" \
  --config-name "${config}" \
  ++train_data_set_list="data/${train_set}/audio_datasets.jsonl" \
  ++valid_data_set_list="data/${valid_set}/audio_datasets.jsonl" \
  ++tokenizer_conf.token_list="${token_list}" \
  ++frontend_conf.cmvn_file="data/${train_set}/am.mvn" \
  ++output_dir="${exp_dir}/exp/${model_dir}" &> ${log_file}
fi



# Testing Stage
if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
  echo "stage 5: Inference"

  if [ ${inference_device} == "cuda" ]; then
      nj=$(echo $CUDA_VISIBLE_DEVICES | awk -F "," '{print NF}')
  else
      inference_batch_size=1
      CUDA_VISIBLE_DEVICES=""
      for JOB in $(seq ${nj}); do
          CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"-1,"
      done
  fi

  for dset in ${test_sets}; do

    inference_dir="${exp_dir}/exp/${model_dir}/inference-${inference_checkpoint}/${dset}"
    _logdir="${inference_dir}/logdir"
    echo "inference_dir: ${inference_dir}"

    mkdir -p "${_logdir}"
    data_dir="data/${dset}"
    key_file=${data_dir}/${inference_scp}

    split_scps=
    for JOB in $(seq "${nj}"); do
        split_scps+=" ${_logdir}/keys.${JOB}.scp"
    done
    utils/split_scp.pl "${key_file}" ${split_scps}

    gpuid_list_array=(${CUDA_VISIBLE_DEVICES//,/ })
    for JOB in $(seq ${nj}); do
        {
          id=$((JOB-1))
          gpuid=${gpuid_list_array[$id]}

          export CUDA_VISIBLE_DEVICES=${gpuid}
          python ../funasr/bin/inference.py \
          --config-path="${exp_dir}/exp/${model_dir}" \
          --config-name="config.yaml" \
          ++init_param="${exp_dir}/exp/${model_dir}/${inference_checkpoint}" \
          ++tokenizer_conf.token_list="${token_list}" \
          ++frontend_conf.cmvn_file="data/${train_set}/am.mvn" \
          ++input="${_logdir}/keys.${JOB}.scp" \
          ++output_dir="${inference_dir}/${JOB}" \
          ++device="${inference_device}" \
          ++ncpu=1 \
          ++disable_log=true \
          ++batch_size="${inference_batch_size}" &> ${_logdir}/log.${JOB}.txt
        }&

    done
    wait

    mkdir -p ${inference_dir}/1best_recog
    for f in token score text; do
        if [ -f "${inference_dir}/${JOB}/1best_recog/${f}" ]; then
          for JOB in $(seq "${nj}"); do
              cat "${inference_dir}/${JOB}/1best_recog/${f}"
          done | sort -k1 >"${inference_dir}/1best_recog/${f}"
        fi
    done

    echo "Computing WER ..."
    python utils/postprocess_text_zh.py ${inference_dir}/1best_recog/text ${inference_dir}/1best_recog/text.proc
    python utils/postprocess_text_zh.py  ${data_dir}/text ${inference_dir}/1best_recog/text.ref
    python utils/compute_wer.py ${inference_dir}/1best_recog/text.ref ${inference_dir}/1best_recog/text.proc ${inference_dir}/1best_recog/text.cer
    tail -n 3 ${inference_dir}/1best_recog/text.cer
  done

fi