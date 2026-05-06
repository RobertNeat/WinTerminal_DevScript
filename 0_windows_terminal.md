# Windows Terminal

Aplikacja pełniąca rolę nakładki graficznej (shell host/ terminal emulator). Nie jest powłoką systemową, służy jedynie jako pojemnik uruchamiający inne powłoki i aplikacje CLI.
Sam nie wykonuje żadnych poleceń, ponieważ nie jest powłoką (shellem). Jego zadaniem jest renderowanie tekstu produkowanego przez procesy potomne (cmd, PowerShell, bash, etc.).

Windows terminal pozwala na:

- obsługę wielu sesji shell'ów za pomocą wielu zakładek,
- umożliwia podział okna na kilka terminali (split view w poziomie lub w pionie, także zagnieżdżone),
- profile poszczególnych powłok (shell) z możliwością personalizacji działania i wyglądu,
- definicja motywów i kolorów dla poszczególnych powłok,
- możliwość zapisu konfiguracji w pliku settings.json lub konfiguracji graficznej,

---

### Profile

Każdy profil w Terminalu to definicja procesu do uruchomienia (jedyne ograniczenie to uruchamiana aplikacja musi być aplikacją konsolową).

Możliwe do zdefiniowania:

- nazwa zakładki - nazwa zakładki wyświetlana na pasku tytułu,
- ikona zakładki - plik graficzny wyświetlany przed nazwą zakładki,
- katalog startowy - obsługuje zmienne środowiskowe (%USERPROFILE%)
- powłoka (shell) - ścieżka bezwzględna lub nazwa z PATH + argumenty uruchomieniowe w jednym stringu,
- uprawnienia administratora - mozliwość uruchomienia automatycznego monitu UAC przy otwarciu profilu,
- czcionka - krój, rozmiar, grubość tekstu,
- schemat kolorów - wbudowany lub własny profil kolorów, dostosowanie wbudowanych profili kolorów,

Możliwość ustawienia zmiennych:

- "tabColor" - deklaracja koloru zakładki w terminal dla danej powłoki shell,
  [Zmienne windows terminal](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance)

---

### Wersja programu windows terminal

Żeby sprawdzić wersję programu należy rozwinąć z paska zakładek rozwinąć strzałkę i kliknąć "About". Pojawi się okno z informacją o wersji programu.

```
Terminal Windows
Version: 1.24.10921.0
```
