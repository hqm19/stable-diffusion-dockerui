FROM python:3.10.6

WORKDIR /home/sd

ARG PROXY
ARG PORT=7860

# debian 下安装访问 http://deb.debian.org/debian 等需要设置代理
# ENV http_proxy="http://${PROXY}"
# ENV https_proxy="http://${PROXY}"
# ENV all_proxy="socks5://${PROXY}"

# 安装基础包
RUN --mount=type=cache,target=/var/cache/apt \ 
    export http_proxy="http://${PROXY}" https_proxy="http://${PROXY}" all_proxy="socks5://${PROXY}" && \
    env | grep proxy && echo "----- install vim net-tools telnet libgl1 -----" && \
    apt-get update && \
    apt-get install -y vim-tiny net-tools telnet && \
    # resolv ImportError: libGL.so.1: cannot open shared object file: No such file or directory
    # when Launching Web UI with arguments
    # see https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/10411
    apt-get install -y libgl1

# 多分一层，避免因 git clone 失败前面的包要重新安装
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui && \
    # 在 Installing torch and torchvision 之后，设置上网代理
    # sed -i '/startup_timer.record("install torch")/a \ \ \ \ \n\ \ \ \ # ------ add proxy begin ------ \n\ \ \ \ os.environ["http_proxy"] = "http://10.10.0.8:10887"\n\ \ \ \ os.environ["https_proxy"] = "http://10.10.0.8:10887"\n\ \ \ \ os.environ["all_proxy"] = "socks5://10.10.0.8:10887"\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ add proxy end ------' ./modules/launch_utils.py
    sed -i '/startup_timer.record("install torch")/a \ \ \ \ \n\ \ \ \ # ------ add proxy begin ------ \n\ \ \ \ os.environ["http_proxy"] = "http://'${PROXY}'"\n\ \ \ \ os.environ["https_proxy"] = "http://'${PROXY}'"\n\ \ \ \ os.environ["all_proxy"] = "socks5://'${PROXY}'"\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ add proxy end ------' ./stable-diffusion-webui/modules/launch_utils.py && \
    # 在 start() 函数开始时清除代理设置 
    sed -i '/def start():/a \ \ \ \ \n\ \ \ \ # ------ clean proxy begin ------ \n\ \ \ \ os.environ.pop("http_proxy", None)\n\ \ \ \ os.environ.pop("https_proxy", None)\n\ \ \ \ os.environ.pop("all_proxy", None)\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ clean proxy end ------\n\ \ \ \ ' ./stable-diffusion-webui/modules/launch_utils.py

WORKDIR /home/sd/stable-diffusion-webui

# 提前于 webui.sh 安装 torch, torchvision, 方便 docker build 缓存；
# torch版本号来自 stable-diffusion-webui/modules/launch_utils.py
# grep "torch_command = os.environ.get('TORCH_COMMAND'" modules/launch_utils.py | cut -d '"' -f 2 | cut -d '{' -f 1 | xargs -I {} python3 -m {} https://download.pytorch.org/whl/cu118
RUN --mount=type=cache,target=/root/.cache/pip ls -l /root/.cache/pip && \
    # 安装 torch 不能设置代理，否则2g+的包下载不下来
    export http_proxy="" https_proxy="" all_proxy="" && \
    env | grep proxy && echo "----- install torch and torchvision -----" && \
    # resolv the err: Using SOCKS proxy, but the 'socksio' package is not installed
    pip install httpx[socks] && \
    python3 -m pip install torch==2.0.1 torchvision==0.15.2 --extra-index-url https://download.pytorch.org/whl/cu118

# 提前于 webui.sh 安装 clip, openclip，安装 clip 需要开启代理，否则一定失败
RUN --mount=type=cache,target=/root/.cache/pip ls -l /root/.cache/pip && \
    export http_proxy="http://${PROXY}" https_proxy="http://${PROXY}" all_proxy="socks5://${PROXY}" && \
    env | grep proxy && echo "----- install clip and open_clip -----" && \
    grep "clip_package = os.environ.get('CLIP_PACKAGE'" modules/launch_utils.py | cut -d '"' -f 2 | xargs -I {} python3 -m pip install {} && \
    grep "openclip_package = os.environ.get('OPENCLIP_PACKAGE'" modules/launch_utils.py | cut -d '"' -f 2 | xargs -I {} python3 -m pip install {}

# 安装 xformers 前去掉代理 (109.1 MB)，否则极容易中断
RUN --mount=type=cache,target=/root/.cache/pip ls -l /root/.cache/pip && \
    export http_proxy="" https_proxy="" all_proxy="" && \
    env | grep proxy && echo "----- install xformers -----" && \
    grep "xformers_package = os.environ.get('XFORMERS_PACKAGE'" modules/launch_utils.py | cut -d "'" -f 4 | xargs -I {} python3 -m pip install -U -I --no-deps {} && \
    python3 -m pip install ngrok

# 创建 clone.sh 脚本文件
RUN echo "#!/bin/bash" > ./clone.sh && \
    echo "set -Eeuox pipefail"              >>  ./clone.sh && \
    echo 'mkdir -p ./repositories/"$1"'     >>  ./clone.sh && \
    echo 'cd ./repositories/"$1"'           >>  ./clone.sh && \
    echo "git init"                         >>  ./clone.sh && \
    echo 'git remote add origin "$2"'       >>  ./clone.sh && \
    echo 'git fetch origin "$3" --depth=1'  >>  ./clone.sh && \
    echo 'git reset --hard "$3"'            >>  ./clone.sh && \
    chmod +x ./clone.sh

# 提前于 webui.sh 克隆仓库: Stable Diffusion, Stable Diffusion XL, K-diffusion, CodeFormer, BLIP
RUN grep "stable_diffusion_commit_hash = os.environ.get('STABLE_DIFFUSION_COMMIT_HASH'" modules/launch_utils.py | cut -d '"' -f 2 | \
    xargs -I {} ./clone.sh "stable-diffusion-stability-ai" "https://github.com/Stability-AI/stablediffusion.git" {} && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN grep "stable_diffusion_xl_commit_hash = os.environ.get('STABLE_DIFFUSION_XL_COMMIT_HASH'" modules/launch_utils.py | cut -d '"' -f 2 | \
    xargs -I {} ./clone.sh "generative-models" "https://github.com/Stability-AI/generative-models.git" {} 

RUN grep "k_diffusion_commit_hash = os.environ.get('K_DIFFUSION_COMMIT_HASH'" modules/launch_utils.py | cut -d '"' -f 2 | \
    xargs -I {} ./clone.sh "k-diffusion" "https://github.com/crowsonkb/k-diffusion.git" {} 

# CodeFormer 和 BLIP 两个的 github 仓库都需要加代理才能 clone 成功
RUN export http_proxy="http://${PROXY}" https_proxy="http://${PROXY}" all_proxy="socks5://${PROXY}" && \
    env | grep proxy && echo "----- clone CodeFormer and BLIP -----" && \
    grep "codeformer_commit_hash = os.environ.get('CODEFORMER_COMMIT_HASH'" modules/launch_utils.py | cut -d '"' -f 2 | \
    xargs -I {} ./clone.sh "CodeFormer" "https://github.com/sczhou/CodeFormer.git" {} && \
    rm -rf assets inputs && \
    grep "blip_commit_hash = os.environ.get('BLIP_COMMIT_HASH'" modules/launch_utils.py | cut -d '"' -f 2 | \
    xargs -I {} ./clone.sh "BLIP" "https://github.com/salesforce/BLIP.git" {} 

# 提前于 webui.sh 安装 CodeFormer requirements 和 stable-diffusion-webui 自身的 requirements_versions.txt
RUN --mount=type=cache,target=/root/.cache/pip ls -l /root/.cache/pip && \
    echo "----- install CodeFormer requirements -----" && \
    pip install -r ./repositories/CodeFormer/requirements.txt && \
    echo "----- install requirements -----" && \
    pip install -r requirements_versions.txt

# 关闭 venv
ENV use_venv=0
ENV venv_dir="-"
# 设置命令行，加上 --skip-torch-cuda-test
ENV NVIDIA_VISIBLE_DEVICES=all
ENV COMMANDLINE_ARGS="--port ${PORT} --allow-code --medvram --xformers --enable-insecure-extension-access --gradio-auth rtx3090:ST0Nbs5AL+5hy4J --api --skip-torch-cuda-test"

# 执行 ./webui.sh
ARG CACHEBUST=1
RUN chmod +x ./webui.sh &&  ./webui.sh -f

# remove --skip-torch-cuda-test
ENV COMMANDLINE_ARGS="--port ${PORT} --allow-code --medvram --xformers --enable-insecure-extension-access --gradio-auth rtx3090:ST0Nbs5AL+5hy4J --api"

# ENV http_proxy=""
# ENV https_proxy=""
# ENV all_proxy=""

EXPOSE ${PORT}
# #ENTRYPOINT ["/docker/entrypoint.sh"]
# CMD python -u webui.py --listen --port 7860 ${COMMANDLINE_ARGS}