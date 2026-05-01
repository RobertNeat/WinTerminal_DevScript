# Profile w PowerShell

$Profile to automatyczna zmienna wskazująca ścieżkę do pliku profilu bieżącego użytkownika dla bieżącego hosta. Jest to skrypt .ps1, który PowerShell uruchamia automatycznie przy każdym starcie sesji (konfiguracje, aliasy, funkcje etc.).

PowerShell rozróżnia 4 profile według dwóch osi (kto i w jakim hoście):

| Zmienna                         | Ścieżka                                                                      | Zakres                                        |
| ------------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------- |
| $Profile.AllUsersAllHosts       | C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1                       | wszyscy użytkownicy, każdy host               |
| $Profile.AllUsersCurrentHost    | C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1  | wszyscy uzytkownicy, tylko konsola PowerShell |
| $Profile.CurrentUserAllHosts    | C:\Users\Robert\Documents\WindowsPowerShell\profile.ps1                      | Bieżący użytkownik, każdy host                |
| $Profile.CurrentUserCurrentHost | C:\Users\Robert\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 | Bieżący użytkownik, tylko konsola PowerShell  |

Ładowane kolejno od ogólnych do szczegółówych (kolejno j.w.), każdy kolejny profil może rozszerzać lub nadpisywać ustawienia poprzedniego.

Profil wykotrzystywany w aktualnej sesji Powershell zależy od użytkownika (bieżący lub wszyscy),
a także od aplikacji (hosta) który hostuje silmnik PowerShell.
W apikacji Terminal w Windows jest używane 'CurrentUserCurrentHost', modyfikacja za pomocą:

```
code $Profile
```

Dla Powershell w Terminalu Windows to: `C:\Users\Robert\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

Dla Powershell w Extension VisualStudioCode to: `C:\Users\Robert\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1`

Zmiany są niezależne, choć jeśli jest potrzeba zmiany rówloległej to można ustawić w profilu dla **CurrentUserAllHosts**.

---

### Możliwości personalizacji

Personalizacja profilu pozwana na:

- tworzenie apliasów i deklaracji przy starcie danej sesji PowerShell
- dodawania komend startowych (analogicznie jak neofetch do bash.rc w linux lub wywołanie winfetch),
- modyfikacja znaku zachęty za pomocą deklaracji w profilu funkcji o nazwie 'prompt' (wywoływana automatycznie przed każdą linią wejścia) lub uźycia oh-my-posh (instalacja i dodanie wywołania w profilu powershell).
