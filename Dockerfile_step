FROM python:3.10.6

WORKDIR /home/sd

ARG PORT=7860
ARG PROXY

# debian 下安装访问 http://deb.debian.org/debian 等需要设置代理
ENV http_proxy="http://${PROXY}"
ENV https_proxy="http://${PROXY}"
ENV all_proxy="socks5://${PROXY}"

ENV NVIDIA_VISIBLE_DEVICES=all
# Commandline arguments for webui.py, for example: export COMMANDLINE_ARGS="--medvram --opt-split-attention"
ENV COMMANDLINE_ARGS="--port ${PORT} --allow-code --medvram --xformers --enable-insecure-extension-access --gradio-auth rtx3090:ST0Nbs5AL+5hy4J --api --skip-torch-cuda-test"


RUN --mount=type=cache,target=/var/cache/apt \ 
    apt-get update && \
    apt-get install -y vim-tiny net-tools telnet && \
    # resolv ImportError: libGL.so.1: cannot open shared object file: No such file or directory
    # when Launching Web UI with arguments
    # see https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/10411
    apt-get install -y libgl1 && \
    # resolv the err: Using SOCKS proxy, but the 'socksio' package is not installed
    pip install httpx[socks] && \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui

ENV use_venv=0
ENV venv_dir="-"

# 安装 torch 不能设置代理，否则2g+的包下载不下来
ENV http_proxy=
ENV https_proxy=
ENV all_proxy=

WORKDIR /home/sd/stable-diffusion-webui

# insert proxy setting into webui.sh after Installing torch and torchvision
# export http_proxy=http://10.10.0.8:10887
# export https_proxy=http://10.10.0.8:10887
# export all_proxy=socks5://10.10.0.8:10887
# env | grep proxy
#
# 在 Installing torch and torchvision 之后，设置上网代理
#   sed -i '/startup_timer.record("install torch")/a \ \ \ \ \n\ \ \ \ # ------ add proxy begin ------ \n\ \ \ \ os.environ["http_proxy"] = "http://10.10.0.8:10887"\n\ \ \ \ os.environ["https_proxy"] = "http://10.10.0.8:10887"\n\ \ \ \ os.environ["all_proxy"] = "socks5://10.10.0.8:10887"\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ add proxy end ------' ./modules/launch_utils.py
RUN sed -i '/startup_timer.record("install torch")/a \ \ \ \ \n\ \ \ \ # ------ add proxy begin ------ \n\ \ \ \ os.environ["http_proxy"] = "http://'${PROXY}'"\n\ \ \ \ os.environ["https_proxy"] = "http://'${PROXY}'"\n\ \ \ \ os.environ["all_proxy"] = "socks5://'${PROXY}'"\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ add proxy end ------' ./modules/launch_utils.py && \
    # 在 git_clone 之前清除代理设置 
    # sed -i '/git_clone(stable_diffusion_repo, repo_dir(/i \ \ \ \ # ------ clean proxy begin ------ \n\ \ \ \ os.environ.pop("http_proxy", None)\n\ \ \ \ os.environ.pop("https_proxy", None)\n\ \ \ \ os.environ.pop("all_proxy", None)\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ clean proxy end ------\n\ \ \ \ ' ./modules/launch_utils.py  && \
    # 在 start() 函数开始时清除代理设置 
    sed -i '/def start():/a \ \ \ \ \n\ \ \ \ # ------ clean proxy begin ------ \n\ \ \ \ os.environ.pop("http_proxy", None)\n\ \ \ \ os.environ.pop("https_proxy", None)\n\ \ \ \ os.environ.pop("all_proxy", None)\n\ \ \ \ print("Current proxy settings:")\n\ \ \ \ for key in ["http_proxy", "https_proxy", "all_proxy"]:\n\ \ \ \ \ \ \ \ print(f"{key}={os.environ.get(key)}")\n\ \ \ \ # ------ clean proxy end ------\n\ \ \ \ ' ./modules/launch_utils.py  && \
    # 在 install torch 之后，插入一个退出点，方便 docker build 缓存
    sed -i '/startup_timer.record("install torch")/a \ \ \ \ \n\ \ \ \ # ------ make a docker build cache point ------ \n\ \ \ \ if os.getenv("BUILD_STEP") == "1":\n\ \ \ \ \ \ \ \ print("BUILD_STEP is 1, exiting.")\n\ \ \ \ \ \ \ \ sys.exit()\n' ./modules/launch_utils.py  && \
    # 在 clone repositores 之后，插入一个退出点，方便 docker build 缓存
    sed -i '/startup_timer.record("clone repositores")/a \ \ \ \ \n\ \ \ \ # ------ make a docker build cache point ------ \n\ \ \ \ if os.getenv("BUILD_STEP") == "2":\n\ \ \ \ \ \ \ \ print("BUILD_STEP is 2, exiting.")\n\ \ \ \ \ \ \ \ sys.exit()\n' ./modules/launch_utils.py

ARG CACHEBUST=1

ENV BUILD_STEP=1
RUN chmod +x ./webui.sh && env | grep proxy && echo "--- step 1 ---" && ./webui.sh -f
# 检查 webui.sh 的执行状态，并根据该状态决定是否继续
RUN if [ $? -eq 0 ]; then \
        echo "webui.sh step 1 executed successfully, continuing build..."; \
    else \
        echo "webui.sh step 1 execution failed, exiting build..."; \
        exit 1; \
    fi

ENV BUILD_STEP=2
RUN chmod +x ./webui.sh && env | grep proxy && echo "--- step 2 ---" && ./webui.sh -f
# 检查 webui.sh 的执行状态，并根据该状态决定是否继续
RUN if [ $? -eq 0 ]; then \
        echo "webui.sh step 2 executed successfully, continuing build..."; \
    else \
        echo "webui.sh step 2 execution failed, exiting build..."; \
        exit 1; \
    fi

ENV BUILD_STEP=3
RUN chmod +x ./webui.sh && env | grep proxy && echo "--- step 2 ---" && ./webui.sh -f

# remove --skip-torch-cuda-test
ENV COMMANDLINE_ARGS="--port ${PORT} --allow-code --medvram --xformers --enable-insecure-extension-access --gradio-auth rtx3090:ST0Nbs5AL+5hy4J --api"

# ENV http_proxy=""
# ENV https_proxy=""
# ENV all_proxy=""

# EXPOSE 7860
# #ENTRYPOINT ["/docker/entrypoint.sh"]
# CMD python -u webui.py --listen --port 7860 ${COMMANDLINE_ARGS}