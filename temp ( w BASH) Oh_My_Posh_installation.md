# Założenia początkowe
Stan na 09.12.2025 (wersja oh-my-posh v28.1.1)

1) Zainstalowany windows Terminal (domyślnie zainstalowany w windows 11):

    https://apps.microsoft.com/detail/9n0dx20hk701?hl=pl-PL&gl=PL

2) Zainstalowany git 2.52.0 \<potrzebujemy git bash\> (autoryzacja tokenem przez SSH lub git credential manager):

    https://git-scm.com/install/

3) Oh my posh jest opisany w dalszej części (będzie instalowany):

    https://ohmyposh.dev/


## Etapy instalacji

1. Dodanie profilu dla GitBash w windows Terminalu

--> Settings (strzałka obok otwarcia nowej karty)

--> + Add new profile

--> New empty profile

```
Name: Git_Bash
Command line: "C:\Program Files\Git\bin\bash.exe" --login -i << ale można sprawdzić za pomocą "where git" w git bash
Starting directory: << bazowa ścieżka dla folderu repozytoriów
Icon: file/browse/"C:\Program Files\Git\mingw64\share\git\git-for-windows.ico
"
Tab title: Git_Bash
Run profile as Administrator: \<NO\>
Hide profile from dropdown: \<NO\>
Appearance: Dark+
Terminal emulation: << zostawić niezmienione
Advanced: << zostawić niezmienione
```

--> Open JSON file
można zmienić kolejność profili w panelu

2. Instalacja oh-my-posh

--> w terminalu (normalnie nie jako administrator)

```
winget install JanDeDobbeleer.OhMyPosh --source winget
```

3. Instalacja motywu i czcionki

- Instalacja motywu
https://ohmyposh.dev/docs/themes
https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/marcduiker.omp.json

--> trzeba pobrać plik json (można z terminala)
Invoke-WebRequest -Uri https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/marcduiker.omp.json -OutFile $env:USERPROFILE\marcduiker.omp.json



- Instalacja nerd font (poprawne wyświetlanie ikon w theme) .. normalnie w gui

Dla theme "marcduiker" trzeba zainstalować najlepiej "CaskaydiaCoveNerdFont-Regular.ttf"
https://ohmyposh.dev/docs/installation/fonts
https://www.nerdfonts.com/font-downloads

--> trzeba wybrać w profilu git bash w terminalu, żeby profil korzystał z tego font
--> Appearance
--> Font face: "CaskaydiaCove Nerd Font"

4. Konfiguracja git bash 
- Dodanie uruchomiania theme do .bashrc


--> w git bash terminalu
```
nano ~/.bashrc
```

--> dodajemy wpis i zapisujemy .bashrc
```
eval "$(oh-my-posh init bash --config 'C:/Users/TwojeKonto/marcduiker.omp.json')"
```

--> trzeba zmienić .bashrc_profile żeby ładował .bashrc
```
nano ~/.bash_profile
```

--> dodajemy wpis na poczatku i zapisujemy .bash_profile
```
# Ładuj ~/.bashrc
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

- Ustawienie profilu jako domyślnego
--> Startup
--> Default profile: Git_Bash