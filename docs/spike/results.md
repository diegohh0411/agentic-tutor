# Spike results

## Smart Turn probe

| Recording | Complete probability | Pre-pause probability | Inference |
| --- | ---: | ---: | ---: |
| en-01 | 0.990 | — | 8.0 ms |
| en-08 | 0.990 | 0.990 | — |
| en-09 | 0.988 | 0.983 | — |
| en-10 | 0.986 | 0.984 | — |
| es-08 | 0.985 | 0.990 | — |
| es-09 | 0.990 | 0.949 | — |
| es-10 | 0.987 | 0.979 | — |

## Phonon probe

| Engine | Voice | Language | Time to first chunk | Real-time factor |
| --- | --- | --- | ---: | ---: |
| Phonon | NbpkqMVS3CJeq2j8 | en | 0.038 s | 32.69 |
| Phonon | Sx8m6WdXBG06zwZT | es | 0.026 s | 34.57 |

## Nemotron ASR probe

| Language | Recording | WER | Reference | Transcript |
| --- | --- | ---: | --- | --- |
| en | en-01 | 0.000 | What is seven times eight? | What is seven times eight |
| en | en-02 | 0.000 | Add three quarters and one half. | Add three quarters and one half |
| en | en-03 | 0.000 | Solve x plus five equals twelve. | solve X plus five equals twelve |
| en | en-04 | 0.000 | Divide ninety by six. | Divide ninety by six |
| en | en-05 | 0.000 | What is the perimeter of this triangle? | What is the perimeter of this triangle |
| en | en-06 | 0.000 | Convert two point five meters to centimeters. | Convert two point five meters to centimeters |
| en | en-07 | 0.000 | Explain why a negative times a negative is positive. | Explain why a negative times a negative is positive |
| en | en-08 | 0.000 | I think the hypotenuse of a right…  triangle is ten. | I think the hypotenuse of a right triangle is ten |
| en | en-09 | 0.000 | First I multiply four by…  seven and get twenty-eight. | First I multiply four by seven and get twenty eight |
| en | en-10 | 0.000 | The answer to this fraction problem is…  three fifths. | The answer to this fraction problem is three fifths |
| es | es-01 | 0.000 | ¿Cuánto es tres cuartos más un medio? | ¿Cuánto es tres cuartos más un medio |
| es | es-02 | 0.200 | ¿Qué es siete por ocho? | Qué ¿7 por ocho |
| es | es-03 | 0.000 | Resuelve x más cinco es igual a doce. | resuelve X más cinco es igual a doce |
| es | es-04 | 0.000 | Divide noventa entre seis. | Divide noventa entre seis |
| es | es-05 | 0.000 | ¿Cuál es el perímetro de este triángulo? | ¿Cuál es el perímetro de este triángulo? |
| es | es-06 | 0.000 | Convierte dos punto cinco metros a centímetros. | Convierte dos punto cinco metros a centímetros |
| es | es-07 | 0.000 | Explica por qué un negativo por un negativo es positivo. | Explica por qué un negativo por un negativo es positivo |
| es | es-08 | 0.000 | Creo que la hipotenusa de un triángulo rectángulo…  mide diez. | Creo que la hipotenusa de un triángulo rectángulo mide 10 |
| es | es-09 | 0.250 | Primero multiplico cuatro por…  siete y obtengo veintiocho. | Primero multiplica cuartos por 7 y obtengo veintiocho |
| es | es-10 | 0.000 | La respuesta de este problema de fracciones es…  tres quintos. | La respuesta de este problema de fracciones es tres quintos |

Mean en WER: 0.000.

Mean es WER: 0.045.

## Qwen tutor probe

Model mlx-community/Qwen3.5-4B-4bit, temperature 0.6, max 300 tokens, thinking disabled. Tokens/s is generated tokens over the time after the first token.

| Language | Prompt | TTFT | Tokens/s |
| --- | --- | ---: | ---: |
| en | What is seven times eight? | 0.155 s | 44.15 |
| en | Can you help me subtract forty-seven from ninety-two? | 0.166 s | 43.67 |
| en | I think eighteen plus twenty-seven is thirty-five. | 0.164 s | 44.09 |
| en | How can I divide eighty-four by six? | 0.163 s | 42.74 |
| en | How can I check whether sixty-three divided by nine is correct? | 0.163 s | 41.65 |
| en | What does the six mean in four thousand six hundred seventy-two? | 0.165 s | 40.91 |
| en | Which is greater: five thousand ninety or five thousand nine hundred? | 0.167 s | 41.08 |
| en | I think one half plus one third is two fifths. | 0.166 s | 39.77 |
| en | How can I compare three fourths and two thirds? | 0.166 s | 39.09 |
| en | What is two point five plus zero point seven? | 0.165 s | 40.36 |
| en | Why is zero point forty-five less than zero point five? | 0.166 s | 39.98 |
| en | How many sides does a hexagon have? | 0.165 s | 39.19 |
| en | How do I find the area of a rectangle that is eight units long and three units wide? | 0.194 s | 35.73 |
| en | I think a square with side length four has area eight. | 0.169 s | 35.30 |
| en | How is perimeter different from area for a rectangle? | 0.171 s | 35.55 |
| en | What number comes next: two, five, eight, eleven? | 0.174 s | 35.87 |
| en | The pattern is three, six, nine, twelve. What is the rule? | 0.186 s | 34.83 |
| en | If a rule doubles a number and then adds one, what happens to four? | 0.160 s | 34.62 |
| en | In a table, x is one, two, three and y is four, seven, ten. What pattern do you see? | 0.197 s | 33.19 |
| en | Can you help me make a number pattern that adds five each time? | 0.170 s | 33.22 |
| es | ¿Cuánto es siete por ocho? | 0.226 s | 32.25 |
| es | ¿Me ayudas a restar cuarenta y siete de noventa y dos? | 0.227 s | 31.06 |
| es | Creo que dieciocho más veintisiete es treinta y cinco. | 0.230 s | 30.16 |
| es | ¿Cómo puedo dividir ochenta y cuatro entre seis? | 0.218 s | 29.58 |
| es | ¿Cómo puedo comprobar si sesenta y tres entre nueve está correcto? | 0.235 s | 28.29 |
| es | ¿Qué valor tiene el seis en cuatro mil seiscientos setenta y dos? | 0.227 s | 28.64 |
| es | ¿Cuál es mayor: cinco mil noventa o cinco mil novecientos? | 0.220 s | 29.67 |
| es | Creo que un medio más un tercio es dos quintos. | 0.226 s | 29.64 |
| es | ¿Cómo puedo comparar tres cuartos y dos tercios? | 0.233 s | 29.19 |
| es | ¿Cuánto es dos punto cinco más cero punto siete? | 0.238 s | 28.91 |
| es | ¿Por qué cero punto cuarenta y cinco es menor que cero punto cinco? | 0.238 s | 29.17 |
| es | ¿Cuántos lados tiene un hexágono? | 0.221 s | 28.38 |
| es | ¿Cómo saco el área de un rectángulo de ocho unidades de largo y tres de ancho? | 0.227 s | 27.98 |
| es | Creo que un cuadrado de lado cuatro tiene área de ocho. | 0.224 s | 27.68 |
| es | ¿Qué diferencia hay entre el perímetro y el área de un rectángulo? | 0.222 s | 27.53 |
| es | ¿Qué número sigue: dos, cinco, ocho, once? | 0.228 s | 27.74 |
| es | La secuencia es tres, seis, nueve, doce. ¿Cuál es la regla? | 0.243 s | 26.30 |
| es | Si una regla duplica un número y luego suma uno, ¿qué pasa con cuatro? | 0.227 s | 27.87 |
| es | En una tabla, x es uno, dos, tres y y es cuatro, siete, diez. ¿Qué patrón ves? | 0.234 s | 26.63 |
| es | ¿Me ayudas a hacer una secuencia que sume cinco cada vez? | 0.225 s | 26.41 |

Median TTFT 0.207 s; median tokens/s 32.72.
| Phonon | NbpkqMVS3CJeq2j8 | en | 0.007 s | 34.39 |
| Phonon | Sx8m6WdXBG06zwZT | es | 0.006 s | 35.82 |

## Echo self-test (spike item 5)

Built-in speakers, no headphones, voice processing on, MacBook Pro M4 Max. Probe phrase: "This is a short echo test. One, two, three." (3.5 s) played through `AudioIO`; Silero VAD chunks (32 ms) above 0.5 are counted while it plays. Leak rule: 3 or more chunks.

| Run | Ambient baseline (silent playback) | While probe plays | Result |
| --- | ---: | ---: | --- |
| 1 | 0 / 109 | 4 / 109 | leaks |
| 2 | 0 / 112 | 0 / 109 | clean |
| 3 | 0 / 109 | 4 / 112 | leaks |

Two earlier runs in a room with background speech gave baselines of 55 to 68 chunks, so they say nothing about echo.

Verdict: marginal. Echo cancellation removes most of the playback but a few chunks still reach the VAD in two of three quiet runs, so the 3-chunk rule trips by one chunk. Under the plan, the headphones banner can show on first start; it is advisory and the conversation still starts. `duck()` takes effect in about 0.03 ms (limit 10 ms). Outstanding: re-run in the owner's real room, and consider raising the leak threshold (for example to 6 chunks) if the banner shows too often with no audible echo.

Environment notes: the engine fails to initialize with voice processing on unless the mixer-to-output connection uses the output node's own format (fixed in `AudioIO`). Starting a voice-processing session straight after another one ended sometimes leaves the output silent (HAL start error 35); an app runs one long session, so this only affects back-to-back probe runs.
