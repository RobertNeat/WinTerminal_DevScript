# Typy plików powershell w projekcie wielomodułowym (powershell 5)

W projekcie wielomodułowym tworzy się pliki:

- .ps1 - PowerShell Script File
- .psm1 - PowerShell Module File
- .psd1 - PowerShell Data File / Manifest

---

### .ps1 - plik skryptu

Zawiera kod Powershell (definicje wywołń funkcji, zmienne, logikę biznesową, importy modułów), jest stworzony do bezpośredniego wywoływania. Zazwyczaj jest to punkt wejścia do projektu, który może być uruchamiany ręcznie lub jako część większego procesu automatyzacji.

```
# myscript.ps1
Import-Module ./ComputeLogicModule.psm1

$input = Get-Content .\input.txt
$result = Compute-SomeLogic -InputData $input

Write-Output $result
```

### .psm1 - plik modułu

Definiuje moduł Powershell (zbiór definicji funkcji, klas, zmiennych), który może być importowany do innych skryptów lub modułów. Plik .psm1 jest używany do organizowania kodu w moduły, które mogą być ponownie używane i łatwo zarządzane. Zazwyczaj importowane w plikach .ps1 za pomocą polecenia `Import-Module`.

```
# MyMathModule.psm1

function Add-Numbers {
    param ($a, $b)
    return $a + $b
}

function Substract-Numbers {
    param ($a, $b)
    return $a * $b
}

Export-ModuleMember -Function Add-Numbers
```

### .psd1 - plik manifestu modułu

Plik manifestu modułu (.psd1) zawiera metadane o module, takie jak jego nazwa, wersja, autor, wymagania dotyczące innych modułów, eksportowane funkcje i inne informacje konfiguracyjne ( w formie klucz-wartość). Jest używany do definiowania właściwości modułu i jego zależności, co ułatwia zarządzanie modułami w większych projektach.

```
@{
    RootModule        = 'MyMathModule.psm1'
    ModuleVersion     = '1.0.0'
    Author            = 'RobertNeat'
    Description       = 'Provides math-related utility functions.'
    FunctionsToExport = @('Add-Numbers')
    PrivateData       = @{}
}
```
