Output demo/npm.gif

Require devbox

Set Shell "bash"
Set FontSize 18
Set Width 1000
Set Height 680
Set Padding 20
Set TypingSpeed 60ms
Set Theme "Catppuccin Mocha"

Hide
Type "export PS1='$ ' && rm -rf /tmp/myapp && cp -r demo/npm /tmp/myapp && cd /tmp/myapp && devbox run -q true && clear"
Enter
Sleep 3s
Show

Type "devbox run pick:npm"
Sleep 400ms
Enter
Sleep 2s

Type "dev"
Sleep 1s
Type ":a"
Sleep 1.2s
Enter
Sleep 3s

Type "devbox run pick:npm"
Enter
Sleep 1.5s
Type "build"
Sleep 1.2s
Enter
Sleep 3.5s
