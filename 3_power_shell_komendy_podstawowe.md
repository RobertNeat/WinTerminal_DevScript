# Budowa poleceń (cmdlet'y)

Powershell używa ścisłej konwencji nazewniczej opartej na schemacie:
`Czasownik-Rzeczownik`
Na przykład: Get-Item, Set-Location, Remove-File, New-Item

---

## Dozwolone Czasowniki

Powershell ma oficjalną listę zatwierdzonych czasowników (Get-Verb), która jest niezmienna.
Wystepuje podział ze względu na grupy windows:

- **Common**

| Kategoria funkcjonalna  | Verbs                                                    |
| ----------------------- | -------------------------------------------------------- |
| Odczyt                  | Get, Find, Search, Watch                                 |
| Modyfikacja             | Set, Add, Remove, Clear, Reset, Redo, Undo               |
| Tworzenie elementów     | New                                                      |
| Operacje na elementach  | Copy, Move, Rename, Resize, Split, Join, Pop, Push, Skip |
| Filtrowanie / nawigacja | Select, Step, Switch, Enter, Exit                        |
| Formatowanie wyjścia    | Format                                                   |
| Widoczność              | Show, Hide                                               |
| Stan zasobu             | Open, Close, Lock, Unlock                                |
| Optymalizacja           | Optimize                                                 |

- **Data**

| Kategoria funkcjonalna | Verbs                                                    |
| ---------------------- | -------------------------------------------------------- |
| Zarządzanie danymi     | Backup, Restore, Save, Checkpoint                        |
| Analiza danych         | Compare, Group, Limit                                    |
| Transformacja danych   | Compress, Expand, Convert, ConvertFrom, ConvertTo, Merge |
| Synchronizacja         | Sync, Update                                             |
| Import / eksport       | Import, Export, Publish, Unpublish, Out                  |
| Edycja / inicjalizacja | Edit, Initialize                                         |
| System plików          | Mount, Dismount                                          |

- **Lifecycle**

| Kategoria funkcjonalna    | Verbs                                       |
| ------------------------- | ------------------------------------------- |
| Cykl życia procesu/usługi | Start, Stop, Restart, Suspend, Resume, Wait |
| Włączanie / wyłączanie    | Enable, Disable                             |
| Instalacja                | Install, Uninstall                          |
| Rejestracja               | Register, Unregister                        |
| Wykonanie                 | Invoke, Submit, Request                     |
| Zatwierdzanie             | Approve, Deny, Confirm                      |
| Walidacja / zakończenie   | Assert, Complete                            |

- **Diagnostic**

| Kategoria funkcjonalna  | Verbs                    |
| ----------------------- | ------------------------ |
| Diagnostyka             | Debug, Trace, Test, Ping |
| Analiza                 | Measure                  |
| Naprawa / rozwiązywanie | Repair, Resolve          |

- **Communications**

| Kategoria funkcjonalna | Verbs               |
| ---------------------- | ------------------- |
| Połączenie             | Connect, Disconnect |
| Przesyłanie danych     | Send, Receive       |
| Wejście / wyjście      | Read, Write         |

- **Security**

| Kategoria funkcjonalna | Verbs              |
| ---------------------- | ------------------ |
| Uprawnienia            | Grant, Revoke      |
| Blokowanie dostępu     | Block, Unblock     |
| Ochrona danych         | Protect, Unprotect |

- **Other**

| Kategoria funkcjonalna | Verbs |
| ---------------------- | ----- |
| Inne                   | Use   |

---

## Dozwolone Rzeczowniki

Rzeczowniki, to obiekty na których operuje dany cmdlet. Powershell nie ma zdefiniowanej listy dla rzeczowników, ponieważ każdy program może definiować własne typu obiektów na których może operować. Zazwyczaj rzeczownik przybiera formę pojedynczą nawet w przypadku jeśli komenda zwraca wiele obiektów.

Do najczęściej używanych rzeczowników mozna zaliczyć.

| Rzeczownik        | Opis                                          |
| ----------------- | --------------------------------------------- |
| `Location`        | Bieżący katalog roboczy                       |
| `Item`            | Plik lub katalog (uniwersalny)                |
| `ChildItem`       | Zawartość katalogu                            |
| `Content`         | Zawartość pliku tekstowego                    |
| `ItemProperty`    | Właściwości elementu (rejestr i metadane)     |
| `Path`            | Operacje na ścieżkach                         |
| `Hash`            | Hash pliku (MD5, SHA256 itd.)                 |
| `Process`         | Procesy systemowe                             |
| `Service`         | Usługi Windows                                |
| `Event`           | Zdarzenia systemowe                           |
| `Counter`         | Liczniki wydajności                           |
| `ExecutionPolicy` | Polityka uruchamiania skryptów                |
| `Variable`        | Zmienne w sesji                               |
| `Env`             | Zmienne środowiskowe (Env:)                   |
| `Module`          | Moduły PowerShell                             |
| `Transcript`      | Zapis sesji do pliku                          |
| `Culture`         | Ustawienia regionalne                         |
| `TimeZone`        | Strefa czasowa                                |
| `Object`          | Operacje na obiektach w potoku                |
| `Member`          | Właściwości i metody obiektu                  |
| `Output`          | Zapis do potoku                               |
| `Error`           | Zapis błędu                                   |
| `Host`            | Zapis bezpośrednio do konsoli (poza potokiem) |
| `Clipboard`       | Schowek systemowy                             |
| `WebRequest`      | HTTP request                                  |
| `RestMethod`      | HTTP request z auto-parsowaniem JSON          |
| `Command`         | Dostępne cmdlety, funkcje, aliasy             |
| `Alias`           | Aliasy komend                                 |
| `Date`            | Aktualna data i czas                          |
| `Random`          | Losowa liczba lub element                     |
| `Job`             | Zadania w tle (asynchroniczne)                |

---

### Cheatsheet najczęściej używanych cmdletów

| Alias | CMD'let                      | Opis                                |
| ----- | ---------------------------- | ----------------------------------- |
| ls    | Get-ChildItem                | lista plików/katalogów              |
| cd    | Set-Location                 | zmiana bieżącego katalogu na podany |
| pwd   | Get-Location                 | Wyśiwet bieżący katalog             |
| mkdir | New-Item -ItemType Directory | Utwórz katalog                      |
| cp    | Copy-Item                    | kopiuj plik/katalog                 |
| mv    | Move-Item                    | przenieś lub zmień nazwę            |
| rm    | Remove-Item                  | usuń plik/katalog                   |
| ni    | New-Item                     | utwórz plik                         |
| cat   | Get-Content                  | odczytaj zawartość pliku            |
|       | Set-Content                  | Nadpisz zawartośc pliku             |
|       | Add-Content                  | Dopisz do pliku (append)            |
|       | Get-ComputerInfo             | informacje o systemie               |

Aby sprawdzić jakie operacje można wykonac na danym obiekcie (rzeczowniku) należy wykonać komendę:
`Get-Command -Noun Path` (w tym przypadku: jakie operacje można wykonać ze ścieżką)
zwróci ona listę wszystkich możliwych cmdletów z udziałem tego obiektu.
Aby sprawdzić na jakich obiektach można wywołać dana czynność można wykorzystać:
`Get-Command -Verb Get` (w tym przypadku: na jakich obiektach można wywołać pobranie).

---

### Pełne komendy i aliasy (do nazewnictwa z bash)

Do sprawdzenia pełnej listy aliasów złuży komenda `Get-Alias`, która zwraca pełną nazwę cmdletu przypisaną do danego aliasu.
Żeby poznać alias dla danego cmdletu (pełna nazwa -> skrócony alias) należy użyć komendy `Get-Alias -Definition Get-Process`, która zwróci skróconą wersję (analogiczną do zapisu bash).
Żeby poznać pełną nazwę danego cmdletu na podstawie nazwy aliasu należy użyć komendy `Get-Alias ls` (gdzie ls to nazwa danego aliasu).

---

### Typy zmiennych w powershell

Deklaracja zmiennej zaczyna się od `$`. Powershell automatycznie wykrywa jej typ na podstawie przypisanej wartości (inferencja). Wpisanie `[typ]` przed nazwą zmiennej wymusza wskazany typ i powershell zgłosi błąd przy próbie przypisania niezgodnej wartości. Parsowanie jest możliwe poprzez dodanie rządanego typu przed definicją typu danej wartości (np. [int][char]'a' zwróci wartość unicode znaku 'a') lub można jawnie przypisać podczas deklaracji inny typ niz zadeklarowany (np. [string]$a=100 będzie skonwertowanym typem na string czyli '100')

Wartośc zmiennej wypisuje się przez wpisanie `$zmienna` lub `Write-Output` - obie metody trafiają do pipeline i można je przechwycić.
`Write-Host` wypisuje wartość zmiennej bezpośrednio na ekran omijając pipeline.

Interpolacja zmiennych w stringach działa tylko w cudzysłowie `"...$zmienna"` (wartość jest podstawiana zamiast zmiennej czyli ...wartość)
Apostrof `'...$zmienna'` traktuje tekst dosłowanie bez podstawiania wartości (wynikiem jest ...$zmienna)
Jeśli wewnątrz stringa ma być wywołane wyrażenie (wywołanie metody arytmetycznej) należy je opakować w `$(...)`

| Typy prymitywne | Przykład     | Opis                                                                          |
| --------------- | ------------ | ----------------------------------------------------------------------------- |
| [int]           | 99           | 32-bitowa liczba całkowita (od -2 147 483 648 do 2 147 483 647)               |
| [long]          | 9999999999   | 64-bitowa liczba całkowita (od -9,2×10¹⁸ do 9,2×10¹⁸)                         |
| [double]        | 9.99         | 64-bitowa liczba zmiennoprzecinkowa, wysoka precyzja                          |
| [float]         | 9.99         | 32-bitowa liczba zmiennoprzecinkowa, mniejsza precyzja niż double             |
| [decimal]       | 9.99         | 128-bitowa liczba dziesiętna, dokładna (28–29 cyfr) – do obliczeń finansowych |
| [bool]          | $true/$false | Wartość logiczna – prawda lub fałsz                                           |
| [char]          | 'A'          | Pojedynczy znak Unicode (16-bit)                                              |
| [string]        | "text"       | Ciąg znaków Unicode o zmiennej długości                                       |
| [byte]          | 255          | 8-bitowa liczba całkowita bez znaku (0–255)                                   |

Typ zmiennej można sprawdzić za pomocą `.getType()` lub operator `-is [int]`.

| Typy rozszerzone                     | Opis                                                                                    |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| [array]                              | tablica wartości o stałym rozmiarze                                                     |
| [hashtable]                          | kolekcja klucz→wartość bez gwarantowanej kolejności                                     |
| [ordered]                            | kolekcja klucz→wartość z zachowaną kolejnością wstawiania                               |
| [System.Collections.Generic.List[T]] | modyfikowalna tablica wartości o dynamicznym rozmiarze (można dodawać/usuwać elementy)  |
| [xml]                                | dokument XML z nawigacją po węzłach                                                     |
| [regex]                              | wyrażenie regularne do dopasowywania i ekstrakcji tekstu                                |
| [ref]                                | przekazanie zmiennej przez referencję (modyfikacja referencji to modyfikacja oryginału) |
| [scriptblock]                        | blok kodu PowerShell zapisany jako wartość – do późniejszego wykonania                  |
| [datetime]                           | data i godzina                                                                          |
| [timespan]                           | przedział czasu / różnica między datami                                                 |
| [PSCustomObject]                     | obiekt z dowolnie zdefiniowanymi właściwościami                                         |
| [guid]                               | globalnie unikalny identyfikator (UUID)                                                 |
| [version]                            | numer wersji w formacie major.minor.build.revision – porównywalny operatorami > <       |
| [uri]                                | adres URL/URI z rozbitymi składowymi (host, port, ścieżka…)                             |
| [environment]                        | dostęp do zmiennych środowiskowych systemu                                              |
