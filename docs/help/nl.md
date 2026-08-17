# Awalé spelen

Awalé is een zaaispel uit de mankalafamilie, gespeeld in West-Afrika en het
Caribisch gebied. Het staat ook bekend als oware, awélé en wari. Dit programma
volgt de Oware Abapa-regels, die in wedstrijden worden gebruikt.

Twee spelers, achtenveertig zaadjes, twaalf kuiltjes. Geen dobbelstenen, geen
verborgen informatie: alles ligt op het bord.

## Het bord

Jij zit aan de onderste rij, de computer aan de bovenste. Ieder bezit de zes
kuiltjes aan de eigen kant en een voorraad aan het einde van de rij waar de
veroverde zaadjes komen.

```
                     computer
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                        jij
```

Het spel begint met vier zaadjes in elk kuiltje. De zaadjes gaan **tegen de
klok in**: langs je eigen rij van kuiltje 1 naar kuiltje 6, dan de rij van de
computer in, en zo verder rond.

## Jouw beurt

Kies een van **jouw** kuiltjes dat niet leeg is. Neem alle zaadjes eruit en leg
ze één voor één in de volgende kuiltjes, tegen de klok in.

Je speelt je kuiltje 3, waar vier zaadjes in liggen:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    4
  [ 0 ]                                   [ 0 ]
           4    4    4    4    4    4
          (1)  (2)  (3)  (4)  (5)  (6)
                      ^ hier speel je
```

De vier zaadjes gaan naar je kuiltjes 4, 5 en 6, en dan naar kuiltje 1 van de
computer:

```
          (6)  (5)  (4)  (3)  (2)  (1)
           4    4    4    4    4    5
  [ 0 ]                                   [ 0 ]
           4    4    0    5    5    5
          (1)  (2)  (3)  (4)  (5)  (6)
```

Je kuiltje 3 is nu leeg, en het zaadje dat je rij verliet is in kuiltje 1 van
de computer beland.

Liggen er twaalf zaadjes of meer in een kuiltje, dan gaat het zaaien helemaal
rond het bord. Het kuiltje waar je begon wordt dan **overgeslagen** en blijft
leeg.

## Veroveren

Je verovert als **beide** dingen waar zijn:

- je **laatste** zaadje landt in een kuiltje van de **computer**, en
- dat kuiltje bevat daarna **precies twee of drie** zaadjes.

Die zaadjes gaan van het bord naar jouw voorraad.

Kijk daarna naar het kuiltje ervoor, dat je net had bezaaid. Is dat ook van de
computer en bevat het ook twee of drie zaadjes, neem het dan eveneens. Ga zo
achteruit door tot een kuiltje niet voldoet, of tot je je eigen rij bereikt.
**Eén kuiltje dat niet voldoet stopt de ketting.**

Je laatste zaadje landt in kuiltje 2 van de computer en brengt het op 2. Het
kuiltje ervoor bevat er 3. Beide worden veroverd, vijf zaadjes:

```
   voor                              na
   ... 3    2    1                   ... 3    0    0
       ^    ^    ^                       ^
       |    |    laatste zaadje          hier stopt de ketting
       |    veroverd (2)
       veroverd (3)
```

Een zet die **alle** overgebleven zaadjes van de computer zou veroveren mag,
maar verovert niets: de zaadjes blijven liggen en de computer speelt door.

## De ander voeden

Heeft de computer aan het begin van jouw beurt helemaal geen zaadjes, dan
**moet** je een zet spelen die er minstens één in zijn rij legt. Andere zetten
mogen niet, en het programma laat ze niet toe.

Hetzelfde geldt voor de computer. Kan geen van beiden de ander voeden, dan
eindigt het spel en houdt degene die niet kan zetten de zaadjes die nog op het
bord liggen.

## Hoe het spel eindigt

- Iemand bereikt **25 zaadjes** en heeft gewonnen: meer dan de helft van
  achtenveertig.
- **24 om 24** is gelijkspel.
- Komt dezelfde stelling drie keer voor, of gaan er honderd zetten voorbij
  zonder enige verovering, dan stopt het spel en neemt elke speler de zaadjes
  uit zijn eigen rij.

In dit programma wordt de winnaar aangekondigd zodra die 25 bereikt, maar je
kunt de ronde uitspelen als je wilt.

## Tips

- **Tel voor je zaait.** Volg je zaadjes met je vinger. Weten waar het laatste
  landt is bijna het hele spel.
- **Kuiltjes met één of twee zaadjes zijn het doelwit.** Eén zaadje brengt ze
  op twee of drie. Let net zo goed op die van jezelf als op die van de computer.
- **Een vol kuiltje is een wapen én een risico.** Twaalf zaadjes of meer vegen
  het hele bord af, maar vullen ook de rij van de tegenstander weer.
- **Uithongeren werkt zelden.** Je bent verplicht te voeden, en wie niets meer
  te verliezen heeft is gevaarlijk.
- **Tel tegen het einde.** Zodra 25 voor een kant onbereikbaar is, telt alleen
  nog het eindtotaal.
- **Zet de leermodus aan.** Die wijst de beste zet aan en legt uit waarom. Hij
  dwingt je nooit.

## De hints lezen

Met de leermodus aan markeert een ster het huisje dat de computer zou spelen.
Zijn meerdere zetten even goed, dan krijgen ze allemaal een ster.

De ster komt voort uit het spelen van elke zet en dan twaalf zetten
vooruitkijken, altijd op de sterkste instelling van de computer, welk niveau je
ook hebt gekozen.

Het is de mening van de computer, niet de waarheid, en hij houdt je nooit tegen
om te spelen wat je wilt.

## Met het toetsenbord spelen

| Toets | Wat het doet |
| --- | --- |
| `1` tot `6` | Dat kuiltje van je rij spelen, van links naar rechts |
| `Tab` | Tussen kuiltjes bewegen, ook die van de computer |
| `Ctrl+Z` | Je laatste zet ongedaan maken |
| `Ctrl+N` | Een nieuw spel beginnen |
| `L` | Leermodus aan- of uitzetten |
| `S` | Aantal zaadjes tonen of verbergen |
| `Esc` | Het bord verlaten |

Elk kuiltje meldt zijn nummer en hoeveel zaadjes erin liggen, dus het hele bord
kan hardop worden voorgelezen zonder muis.

## Meer weten

[Mankala op Wikipedia](https://nl.wikipedia.org/wiki/Mankala)
