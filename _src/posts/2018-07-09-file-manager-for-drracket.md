    Title: File Manager for DrRacket
    Date: 2018-07-09T17:35:01
    Tags: DrRacket , Plugin
    Authors: Syntacticlosure

在DrRacket上面写代码是一件痛苦的事情，因为没有文件管理器，所以当有很多文件需要编辑的时候需要
一个一个打开，而且容易打开许多窗口，切换起来也及其麻烦。

为了解决这个问题，我写了一个插件。 

<!-- more -->

![image](https://user-images.githubusercontent.com/22510026/42439375-5663ee04-8395-11e8-84e3-af6a89b32532.png)

要安装她，请使用如下命令：

```
raco pkg install files-viewer
``` 

或者在DrRacket的Package Manager里面搜索files-viewer安装。 

安装完成之后，这时插件还没有被显示，你需要点击view菜单下的show the file manager选项，然后左边就会出现一个文件管理器
。你可以自由拖动她到一个合适的大小，并且下次启动DrRacket依然会以该大小显示。

当你的文件结构发生了变化，请立即使用refresh，文件管理器会自动更新变化。


当你需要编辑某个文件夹下的代码时，请右击文件管理器，选择change the directory，然后选择你需要编辑的文件夹。

当你不需要显示某些文件的时候，使用file filter功能，如不需要显示bak文件，就将file filter配置为 .bak 。

你可以快速在目录下打开命令行，只需要使用open terminal here选项，但是在此之前需要配置与你系统相关的终端启动命令。

如在windows下，你可以使用该配置：

```
start /d ~a cmd
``` 

~a代表所选中的文件所在目录或直接选中的目录。




