Stable Diffusion DockerUI
=======

为 Stable Diffusion 流行的 UI 工程编写的 Dockerfile
-----------

为什么要做这个：
1. 主要目的是为了解决国内网络不稳定不畅通的问题。正常安装过程中，部分资源需要科学上网，部分资源又需要直连才能成功。所以在 Dockerfile 中统一解决这些问题。希望自己和需要的人不需要再重复折腾了。
2. 这个工程 https://github.com/AbdBarho/stable-diffusion-webui-docker 用了下，比较旧了，貌似也不维护了。它其中很多依赖的 repo 都是写死一个 commit ID，让人非常不安。所以自己做一个

主要内容就是两个 Dockerfile：
* Dockerfile_ComfyUI
* Dockerfile_WebUI

可以分别用来一键构建如下 UI 的 Docker 镜像：
* [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
* [ComfyUI](https://github.com/comfyanonymous/ComfyUI)

构建好镜像后，即可反复启动运行。

# linux 环境

## 前置条件

* 科学上网畅通，在 host 本地暴露了代理端口。
* 20G+ 硬盘（后面下载的模型越多，需要的硬盘越多）
* docker 环境可用

以下过程，是在 NVIDIA RTX 3090 上调试通过的。其他非 NVIDIA 硬件环境应该在 torch 安装部分有部分差异，需要根据 webui/comfyui 等文档来调整。

## Stable Diffusion WebUI

### Stable Diffusion WebUI 镜像构建

将 host 本机的 IP 地址和科学上网软件暴露的本地代理端口放到一起，例如：10.10.0.8:10887， 设置为构建参数 PROXY 的值

在构建容器过程中，及将来容器运行中，会从容器中通过 PROXY 指定的IP和端口下载资源

```
git clone git@github.com:hqm19/stable-diffusion-dockerui.git && cd stable-diffusion-dockerui
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
nohup docker build -f ./Dockerfile_WebUI --build-arg PROXY=10.10.0.8:10887 --build-arg PORT=7880 --build-arg AUTH=admin:changeitsoon -t sd-webui:20231208 . > build.log 2>&1 &

tail -100f build.log
```

直到镜像构建完成。如果中途因网络问题中断，只需反复重新执行最后一条 docker build 语句:
```
nohup docker build -f ./Dockerfile_WebUI --build-arg PROXY=10.10.0.8:10887 --build-arg PORT=7880 --build-arg AUTH=admin:changeitsoon -t sd-webui:20231208 . > build.log 2>&1 &
```

直到完成。docker 构建过程会缓存中间结果, 将失败重试时重复的下载和安装降到最低

其中
* --build-arg PROXY=10.10.0.8:10887 指定了构建和运行期需要科学上网时的本地https/http代理
* --build-arg PORT=7880 指定了镜像中的 webui 默认监听端口。也可以在启动容器时被 CMD 参数覆盖
* --build-arg AUTH=admin:changeitsoon 指定了容器服务启动后，默认的账户和密码。
* -t sd-webui:20231208 是构建后的镜像名，tag 建议和 Stable Diffusion WebUI 的更新日期保持一致方便区分
* 最前面的 nohup 和 最后的 > build.log 2>&1 & 是将过程日志重定向到 build.log 方便查看，同时将构建过程放在后台，shell 断连后还能继续构建

镜像构建成功后，可以查看到镜像列表：

```
$ docker images | grep sd-webui
sd-webui     20231208   4455a3303015   6 days ago      7.22GB
```

构建过程做了如下事情：
1. 基于 python:3.10.6 基础镜像，安装常用工具，和 libgl1 包。 webui 依赖这个包。
2. 将 Dockerfile 文件同目录通过 git clone 得到的代码主目录 ./stable-diffusion-webui 拷贝到镜像中
3. 清空代理，从 https://download.pytorch.org/whl/cu118 安装 torch==2.0.1 torchvision==0.15.2 (因为 torch 用代理装太慢并且失败率极高且)
4. 提前安装本来在 webui.sh 中会安装的包，以利用 docker 构建缓存。并且安装不同的包时，根据需要设置好 https 代理
5. 克隆 webui.sh 中会 clone 的 git 仓库到 repositories 目录下，并安装他们对应的依赖。
6. 修改 stable-diffusion-stability-ai 和 generative-models 中，远程访问 https://huggingface.co 的地方为本地访问
7. 设置好合适的参数，执行 ./webui.sh 但是不启动服务。
8. 设置好将来镜像启动时的 CMD 为 ./webui.sh -f

### Stable Diffusion WebUI 模型准备

镜像构建好后，在运行前需要准备好相关模型文件。

本 git 仓库中已经预置了几个空目录用于挂载到容器中，以避免把模型文件、产出文件等直接留在容器中：

* models 放置模型文件。模型体积都比较大。
* extensions 插件目录
* outputs 图片生成后的保存目录
* huggingface.co 放置部分huggingface上的模型文件


启动容器前，需要将 https://huggingface.co/openai/clip-vit-large-patch14/tree/main 里面的11个文件下载下来，按 url 后面的路径放置到 huggingface.co 目录下。这样为了避免 webui 运行的过程中，因访问被屏蔽的网站而失败。上文在容器构建过程中，已经将远程访问 huggingface.co 的地方，修改为了访问本地文件，本地文件的位置就在这里：

```
huggingface.co/
└── openai
    └── clip-vit-large-patch14
        ├── config.json
        ├── flax_model.msgpack
        ├── merges.txt
        ├── model.safetensors
        ├── preprocessor_config.json
        ├── pytorch_model.bin
        ├── special_tokens_map.json
        ├── tf_model.h5
        ├── tokenizer_config.json
        ├── tokenizer.json
        └── vocab.json
```

可以直接运行 huggingface.co/openai/clip-vit-large-patch14 下的 download.sh 来下载这些模型文件：

```
$ cd huggingface.co/openai/clip-vit-large-patch14
$ export https_proxy=http://10.10.0.8:10887 http_proxy=http://10.10.0.8:10887 all_proxy=socks5://10.10.0.8:10887
$ ./download.sh > download.log 2>&1 &
$ tail -f download.log
```
失败可以重新执行，直到下载完成。download.sh 中的 wget -c 参数保证了可以断点续传。

或者也可以用其他工具下载后放置在这个目录。比如用迅雷VIP会员下载就超级快，估计已经提前在国内CDN缓存过了。

另外必要的基础模型可以预先下载到 stable-diffusion-dockerui/models 下的相应目录。一个包含最早的 SD1.5 模型和较新的 SDXL 的最小的模型列表如下：

```
models/
├── Lora
│   └── sd_xl_offset_example-lora_1.0.safetensors
├── Stable-diffusion
│   ├── v1-5-pruned-emaonly.safetensors
│   ├── sd_xl_base_1.0_0.9vae.safetensors
│   └── sd_xl_refiner_1.0_0.9vae.safetensors
└── VAE
    └── sdxl_vae.safetensors
```

### Stable Diffusion WebUI 容器启动

huggingface.co/openai/clip-vit-large-patch14 等模型准备好后，即可回到 stable-diffusion-dockerui 根目录，执行 docker run 启动容器：

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

git clone 本项目并进入根目录，然后 git clone ComfyUI 和其插件：

```
git clone git@github.com:hqm19/stable-diffusion-dockerui.git && cd stable-diffusion-dockerui
git clone https://github.com/comfyanonymous/ComfyUI
mkdir -p ComfyUI/custom_nodes && cd ComfyUI/custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
git clone https://github.com/shadowcz007/comfyui-mixlab-nodes.git
git clone https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet.git
git clone https://github.com/AIGODLIKE/AIGODLIKE-ComfyUI-Translation.git
git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git
cd -
```

以上准备完成后，目录结构应该像下面这样：

```
stable-diffusion-dockerui/
├── Dockerfile_ComfyUI
└── ComfyUI
    └── custom_nodes
        ├── ComfyUI-Manager
        ├── comfyui-mixlab-nodes
        ├── ComfyUI_Custom_Nodes_AlekPet
        ├── AIGODLIKE-ComfyUI-Translation
        ├── ComfyUI-Custom-Scripts
        └── comfyui_controlnet_aux
```

然后在 stable-diffusion-dockerui 根目录下执行 docker build 构建镜像：

```
nohup docker build -f ./Dockerfile_ComfyUI --build-arg PROXY=10.10.0.8:10887 --build-arg PORT=7980 -t sd-comfyui:20231214 . > build.log 2>&1 &
tail -100f build.log
```

直到镜像构建完成。如果中途因网络问题中断，只需反复重新执行这条 build 语句。docker 构建过程会缓存中间结果, 将失败重试时重复的下载和安装降到最低

其中
* --build-arg PROXY=10.10.0.8:10887 指定了构建和运行期需要科学上网时的本地https/http代理
* --build-arg PORT=7980 指定了镜像中的 ComfyUI 默认监听端口。也可以在启动容器时被 CMD 参数覆盖
* -t sd-comfyui:20231214 是构建后的镜像名，tag 建议和 ComfyUI 的更新日期保持一致方便区分
* 最前面的 nohup 和 最后的 > build.log 2>&1 & 是将过程日志重定向到 build.log 方便查看，同时将构建过程放在后台，shell 断连后还能继续构建

镜像构建成功后，可以查看到镜像列表：

```
$ docker images | grep sd-comfyui
sd-comfyui   20231214   d05c3d7ca9d0   10 hours ago    6.51GB
```

构建过程做了如下事情：
1. 基于 python:3.10.6 基础镜像，安装常用工具。
2. 将 Dockerfile 文件同目录通过 git clone 得到的代码主目录 ./ComfyUI 拷贝到镜像中
3. 安装 torch torchvision torchaudio 以 https://download.pytorch.org/whl/cu121 为源
4. 安装 ComfyUI 自身和其插件对应的依赖。
5. 设置好将来镜像启动时的 CMD 为 python -u main.py --listen --port ${PORT}

### ComfyUI 容器启动方式

因模型文件都比较大，所以 ComfyUI 应该和 stable-diffusion-webui 共用模型。模型都放置在 stable-diffusion-dockerui/models 下.
因 webui 和 ComfyUI 模型目录命名有差异，所以需要先在 models 目录下为 ComfyUI 建立软链接：

```
$ ln -s Stable-diffusion checkpoints
$ ln -s VAE vae
$ ln -s Lora loras
$ ln -s ControlNet controlnet
$ ll
lrwxrwxrwx  1 root root   17 Dec 13 07:38 checkpoints -> Stable-diffusion//
drwxr-xr-x  5 root root 4096 Dec 11 13:56 Stable-diffusion/
drwxr-xr-x  2 root root 4096 Dec 11 15:26 Lora/
lrwxrwxrwx  1 root root    5 Dec 13 07:38 loras -> Lora//
lrwxrwxrwx  1 root root    3 Dec 13 07:38 vae -> VAE/
drwxr-xr-x  2 root root 4096 Dec  8 17:24 VAE/
lrwxrwxrwx  1 root root   10 Dec 13 22:24 controlnet -> ControlNet/
drwxr-xr-x  2 root root 4096 Dec 13 22:23 ControlNet/
...
```

软链接准备好后，在 stable-diffusion-dockerui 下执行 docker run 启动 ComfyUI 容器：

```
docker run --name sd-comfyui --gpus all -d -p 7980:7980 \
  -v "${PWD}/ComfyUI/custom_nodes:/home/comfyui/custom_nodes" \
  -v "${PWD}/models:/home/comfyui/models" \
  -v "${PWD}/outputs:/home/comfyui/output" sd-comfyui:20231214
```

其中 -p 7980:7980 指定的端口号, 要和镜像构建时指定的 --build-arg PORT=7980 一致。

也可以在上面 docker run 命令后加如下 CMD 命令，覆盖镜像中默认的端口和参数：

```
docker run --name sd-comfyui --gpus all -d -p 9980:9980 \
  -v "${PWD}/ComfyUI/custom_nodes:/home/comfyui/custom_nodes" \
  -v "${PWD}/models:/home/comfyui/models" \
  -v "${PWD}/outputs:/home/comfyui/output" sd-comfyui:20231214 \
  python -u main.py --listen --port 9980
```

# windows 环境

todo

理论上只要 win10+ 以上，docker 环境没问题，可以一样的操作。

因暂时没有 window 环境，尚未验证。

希望得到您的补充完善。
