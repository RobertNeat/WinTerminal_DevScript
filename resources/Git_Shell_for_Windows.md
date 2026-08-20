# Git for Windows — Bash, MSYS2 i MINGW64

Powłoki `Git for Windows` które są zapewnione z instalacją git za pomocą oficjalnego instalatora.

---

1. Dostępne powłoki (w kolejności wygody użytkowania):

| Shell path                              | Rola                                                                                                      | Środowisko  | Linux-like commands | Windows-like commands |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------- | ------------------- | --------------------- |
| `C:\Program Files\Git\git-bash.exe`     | Launcher kompletnego Git Bash; standardowy sposób uruchamiania Git Bash w osobnym terminalu               | `MINGW64`   | X                   | X                     |
| `C:\Program Files\Git\bin\bash.exe`     | Bash/redirector przygotowany do pracy w środowisku Git for Windows; dobry jako shell dla Windows Terminal | `MINGW64`   | X                   | X                     |
| `C:\Program Files\Git\usr\bin\bash.exe` | Właściwy interpreter Bash należący do warstwy MSYS2                                                       | `MSYS`      | X                   |                       |
| `C:\Program Files\Git\git-cmd.exe`      | Launcher środowiska Git przeznaczonego dla klasycznego Windows CMD                                        | Windows/CMD |                     | X                     |
| `C:\Program Files\Git\bin\git.exe`      | Program `git`, **nie jest shellem**                                                                       | —           |                     |                       |

---

2. Różnica między `MSYS2` a `MINGW64`

**MSYS2** - pełne środiwkso POSIX/UNIX nietolerujące natywnych programów Windows. Dostarcza m.in. Bash oraz unixowe narzędzia: `bash`,`ls`,`cat`,`touch`,`grep`,`sed`,`awk`,`rm`,`cp`,`mv`.
Programy tego typu znajdują się przede wszystkim w `C:\Program Files\Git\usr\bin`.
MSYS2 zapewnia również POSIX-ową reprezentację systemu plików Windows `C:\Users\Robert → /c/Users/Robert` oraz `P:\Projects → /p/Projects`.

**MINGW64** - środowisko łączące POSIX/UNIX z **natywnymi 64-bitowymi programami Windows**.
Narzędzia MSYS2/POSIX są dostępne w `/usr/bin`, a natywne programy Windows w `/mingw64/bin`.
W jednej sesji można mieszać styl Unix i Windows (interoperacyjność koment np. 'ls i dir' a także uruchamianie programów `explorer.exe` `notepad.exe`).
Zapewnia wygodniejsze użycie, uniwersalność komend nawigacji i manipulacji katalogami i plikami.

Aktualne środowisko można sprawdzić przez `echo "$MSYSTEM"`, wynikiem działania jest `MINGW64` lub `MSYS` w zależności od powłoki.

---

## Praktyczny wybór

Dla wygodnego używania zaleca się korzystanie z `MINGW64` w sesji Windows Terminal. Pozwala to na swobodne mieszanie podstawowych konwencji Windows i Unix **MINGW64 jest praktyczniejszym środowiskiem niż bezpośrednia sesja MSYS**.
