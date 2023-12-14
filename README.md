Stable Diffusion DockerUI
=======

为 Stable Diffusion 流行的 UI 工程编写的 Dockerfile, 主要目的是为了解决国内网络不流畅的问题。正常安装过程中，部分资源需要科学上网，部分资源又需要直连才能成功。所以在 Dockerfile 中统一解决这些问题。希望自己和别人不需要重复折腾。
-----------

可以一键构建如下 UI 的 Docker 镜像：
* [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
* [ComfyUI](https://github.com/comfyanonymous/ComfyUI)

构建好镜像后，即可反复启动运行。

# linux 环境

## 前置条件

* 科学上网畅通，在 host 本地暴露了代理端口。
* N卡
* 100G+ 硬盘

## Stable Diffusion WebUI

### Stable Diffusion WebUI 镜像构建过程

将 host 本机的 IP 地址和科学上网软件暴露的本地代理端口放到一起，例如：10.10.0.8:10887， 设置为构建参数 PROXY 的值

在构建容器过程中，及将来容器运行中，会从容器中通过 PROXY 指定的IP和端口下载资源

```
git clone git@github.com:hqm19/stable-diffusion-dockerui.git && cd stable-diffusion-dockerui
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
nohup docker build --build-arg PROXY=10.10.0.8:10887 --build-arg PORT=7880 --build-arg AUTH=admin:changeitsoon -t sd-webui:20231208 . > build.log 2>&1 &

tail -100f build.log
```

直到镜像构建完成。如果中途因网络问题中断，只需反复重新执行最后一条 docker build 语句，直到完成。docker 构建过程会缓存中间结果, 将失败重试时重复的下载和安装降到最低

其中构建参数 PORT 是镜像中的 webui 默认监听端口。也可以在启动容器时被 CMD 参数覆盖

镜像构建好后，可以查看镜像列表：

```
$ docker images | grep sd-webui
sd-webui     20231208   4455a3303015   6 days ago      7.22GB
```

构建过程做了如下事情：
1. 基于 python:3.10.6 基础镜像，安装常用工具，和 libgl1 包。 webui 依赖这个包。
2. 将 Dockerfile 文件同目录通过 git clone 得到的代码主目录 ./stable-diffusion-webui 拷贝到镜像中
3. 清空代理，从 https://download.pytorch.org/whl/cu118 安装 torch==2.0.1 torchvision==0.15.2
4. 提前安装本来在 webui.sh 中会安装的包，以利用 docker 构建缓存。并且安装不同的包时，根据需要设置好 https 代理
5. 克隆 webui.sh 中会 clone 的 git 仓库到 repositories 目录下，并安装他们对应的依赖。
6. 修改 stable-diffusion-stability-ai 和 generative-models 中，远程访问 https://huggingface.co 的地方为本地访问
7. 设置好合适的参数，执行 ./webui.sh 但是不启动服务。
8. 设置好将来镜像启动时的 CMD 为 ./webui.sh -f

### Stable Diffusion WebUI 容器启动方式

构建好镜像后，最好在 stable-diffusion-dockerui 项目根目录下启动。也可以在任意其他目录下启动。

需要在选定目录下，提前创建好需要挂载到容器的目录。一般如下目录需要挂载到容器中，以避免把大文件、产出文件等直接留在容器中：
* models 模型文件。模型体积都比较大。
* extensions 插件目录
* outputs 图片生成后的保存目录
* huggingface.co 


```
mkdir models/ outputs/ extensions/ huggingface.co/
```

然后将 https://huggingface.co/openai/clip-vit-large-patch14/tree/main 这里的文件都下载下来，按 url 后面的路径放置到 huggingface.co 目录下。这样为了避免 webui 运行的过程中，访问被屏蔽的网站而失败。

```
huggingface.co/
└── openai
    └── clip-vit-large-patch14
        ├── config.json
        ├── flax_model.msgpack
        ├── gitattributes
        ├── merges.txt
        ├── model.safetensors
        ├── preprocessor_config.json
        ├── pytorch_model.bin
        ├── README.md
        ├── special_tokens_map.json
        ├── tf_model.h5
        ├── tokenizer_config.json
        ├── tokenizer.json
        └── vocab.json
```

可以在 huggingface.co/openai/clip-vit-large-patch14 下放置一个 download.sh 来下载模型文件：

```
$ cd huggingface.co/openai/clip-vit-large-patch14
$ cat ./download.sh
#!/bin/bash

export https_proxy=http://10.10.0.8:10887 http_proxy=http://10.10.0.8:10887 all_proxy=socks5://10.10.0.8:10887

wget -c -O flax_model.msgpack https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/flax_model.msgpack?download=true
wget -c -O model.safetensors https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/model.safetensors?download=true
wget -c -O pytorch_model.bin https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/pytorch_model.bin?download=true
wget -c -O tf_model.h5 https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tf_model.h5?download=true
wget -c -O config.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/config.json?download=true
wget -c -O tokenizer.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tokenizer.json?download=true
wget -c -O tokenizer_config.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tokenizer_config.json?download=true
wget -c -O config.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/config.json?download=true
...

$ chmod +x 
$ ./download.sh > download.log 2>&1 &
$ tail -f download.log
```
直到下载完成，失败可以重新执行， wget -c 参数保证了可以断点续传。 或者用其他工具下载后放置在这个目录。

huggingface.co/openai/clip-vit-large-patch14 模型准备好后，即可回到运行根目录，执行 docker run 启动容器：

```
docker run --name sd-webui --gpus all -d -p 7880:7880 \
  -v "${PWD}/models:/home/sd-webui/models"  \
  -v "${PWD}/extensions:/home/sd-webui/extensions" \
  -v "${PWD}/huggingface.co:/home/sd-webui/huggingface.co" \
  -v "${PWD}/outputs:/home/sd-webui/outputs" \
  -e COMMANDLINE_ARGS="--listen --port 7880 --allow-code --xformers --enable-insecure-extension-access --gradio-auth admin:changeitsoon" \
  sd-webui:20231208
```

其中 -p 7880:7880 指定的端口号, 及 webui 的命令行参数 COMMANDLINE_ARGS 中指定的 --port 7880 端口号，要和镜像构建时指定的 --build-arg PORT=7880 一致。

镜像启动后，可以查看容器：

```
$ docker ps -a | grep sd-webui
61e65867cbe6   sd-webui:20231208     "/bin/sh -c './webui…"   3 days ago    Up 3 days    0.0.0.0:7880->7880/tcp, :::7880->7880/tcp   sd-webui
```

## ComfyUI

### ComfyUI 镜像构建过程


### ComfyUI 容器启动方式

# windows 环境

todo