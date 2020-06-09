# SLEEPROOM

## Installation
    $ gem install sleeproom

## Dependency
* [Minyami](https://github.com/Last-Order/Minyami)

## Usage
    $ ln -s sleeproom.service /etc/systemd/system/
    $ sudo service sleeproom start
    $ sleeproom status

默认配置文件保存在 ~/.config/sleeproom/base.yml

## TODO
* [ ] 代理支持
* [ ] Web GUI
* [ ] 日志保存

## Service example
```
[Unit]
Description=SLEEPROOM
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=[WorkingDirectory]
ExecStart=[ExecStart]
TimeoutSec=300
Restart=always

[Install]
WantedBy=multi-user.target
```

## License
The gem is available as open source under the terms of the [MIT License](LICENSE.txt).