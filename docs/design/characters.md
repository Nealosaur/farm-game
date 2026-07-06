# Emberhollow — Characters, Dialog & Heart Events

> Implement dialog VERBATIM as data (typos and all — they're voice).
> Pools: STRANGER (L0-1) / ACQUAINT (L2-3) / FRIEND (L4-6) / CLOSE (L7-9) /
> KINDRED (L10). Resolver picks: heart-event-if-pending > birthday > festival
> > rain > seasonal (if present for tier) > tier pool (random, no repeat
> until pool exhausted). Gift reactions override everything for that talk.
> Heart events: one choice, [A]=empathetic (+30), [B]=dismissive (−30).
> Days use day_of_season. Blocks: 6-9 / 9-12 / 12-17 / 17-20 / 20-2.

---

## MARTA — General Store keeper
Warm, brisk, gossip with a kind edge. Widowed; her late husband Tomas wrote
the store's price book by hand. Birthday: **Spring 19**.
**Schedule:** 6-9 store counter; 9-12 store; 12-17 store; 17-20 plaza bench;
20-2 home (mayor-house row). Rain: all blocks store. Festival: plaza stall.
**Gifts:** loves pumpkin, strawberry; likes any crop; dislikes slime_gel
("Off my counter."). **Perks:** L4 5% discount, L7 10%; L5 gift: 3 strawberry
seeds; L8 gift: 200g "loyalty refund."
**STRANGER:** "Welcome to the store. Prices are on the shelf, dear." /
"You're the Hearthstead one? Hm. Your grandmother kept better hours." /
"Coin first, questions after. Store policy." / "Mind the floor, I just swept."
**ACQUAINT:** "Back again! I'll start a tab. I won't honor it, but I'll start
one." / "Turnips are moving well. Folk are hungrier lately." / "The Delve's
got the whole town spooked, you know." / "You look like you slept in a field.
...You did, didn't you."
**FRIEND:** "I saved the good seed packets back for you. Don't tell Alden." /
"Tomas used to say a store's just a pantry with manners." / "You're half the
gossip in this town now. The good half, mostly." / "Eat something before you
go back down that hole. Promise me."
**CLOSE:** "I reopened Tomas's price book last night. First time in years.
Your fault, somehow." / "This counter's seen three mayors and one of you.
You're the interesting one." / "If you ever don't come back from that Delve,
I'm raising your prices posthumously."
**KINDRED:** "Family discount. Don't argue, it's already rung up." /
"Hearthstead and this store — town runs on the pair of us, dear."
**Seasonal:** (Spring/FRIEND+) "Planting weather. Tomas proposed to me in
planting weather." (Winter/any) "Cold keeps the shelves full and the door
shut. Sit a minute."
**Rain:** "Rain's good for exactly two things: crops and my ledger."
**Birthday reaction:** "You remembered?! Even Tomas forgot twice."
**Gift loved:** "Oh, my favorite! You clever thing." **liked:** "That'll do
nicely, thank you." **disliked:** "I... will find a use. Outdoors."
**HEART EVENT L3 — "The Price Book":** Marta is wiping the counter, an old
ledger open. "Tomas priced everything in this town by hand. Even the things
nobody bought. 'Someone might need it someday,' he'd say." She closes it.
"Silly to keep it. Prices change."
[A] "Read me one page?" → she laughs, reads an entry for 'moonlight, per
jar — free'. "...He was ridiculous. Thank you."
[B] "Yeah, old prices are useless." → "...Right. Business as usual, then."
**HEART EVENT L7 — "Restock":** She's up a ladder, restocking the top shelf.
"Tomas's shelf. I've left it empty for six years. Time it earned its keep."
She hands you the first item down: a seed packet marked in faded ink.
[A] "He'd like what you've done with the place." → "He'd like YOU, which is
worse. Take the packet. Grow something loud."
[B] "Finally, more inventory." → "...Yes. Inventory. That's all it was."

---

## STEN — Blacksmith
Gruff, few words, precise. Secretly sentimental about craft. Birthday:
**Winter 8**. **Schedule:** 6-9 smithy; 9-12 smithy; 12-17 smithy; 17-20
saloon; 20-2 home. Rain: no change ("forge doesn't care"). Festival: plaza,
standing at the edge.
**Gifts:** loves goblin_fang, driftglass; likes slime_gel, wisp_dust,
tideshell; dislikes strawberry ("Sticky."). **Perks:** L5 gift: 150g "scrap
credit"; L8 gift: whetstone dialog + 300g.
**STRANGER:** "Forge is hot. Stand back." / "Need something hammered, or
just standing there?" / "Hm." / "The Delve chews up cheap steel. Remember
that."
**ACQUAINT:** "Your sword's holding an edge. Barely." / "Iron sword at
Marta's. My work. Overpriced. Worth it." / "Goblin fang. Good carbon in it.
Odd, that." / "You swing like a farmer. ...That's not an insult. Farmers
work."
**FRIEND:** "Brought the forge up early. Had a feeling you'd come by." /
"Anyone can make sharp. Making TOUGH, that's the trade." / "The old
adventurer, Garrick — we don't talk. Ask him why." / "Show me your blade.
...Fine. FINE work is different from fine."
**CLOSE:** "Started something on the back bench. Not for sale. Maybe for
you, someday, if you stop dying." / "My father shod horses here. His father
too. I make swords for a farmer. World's strange." / "You're the only one
who doesn't flinch at the forge. Noticed that."
**KINDRED:** "Bench is yours whenever. Just put the hammer back straight." /
"Blades I've made that I trust: three. You carry one."
**Seasonal:** (Winter/any) "Forge season. Whole town finally understands my
job." **Rain:** "Rain rusts. Come in or go home."
**Birthday reaction:** "...How did you know that. WHO told you that."
**Gift loved:** "Hm. Good material. Good eye." **liked:** "Usable." 
**disliked:** "No."
**HEART EVENT L3 — "The Rejected Blade":** Sten pulls a sword from the
scrap barrel — beautiful, but with a hairline crack. "Made this at your age.
Judges at the capital called it 'promising.' Promising means no."
[A] "The crack's only in the steel." → long pause. "...Hm. That's either
wise or stupid. I'll take it."
[B] "So sell it cheap." → "It's SCRAP." (he doesn't speak again today)
**HEART EVENT L7 — "Masterwork":** The back bench is uncovered: an unfinished
blade, folded steel, years of dust. "Stopped the day the judges wrote back.
Question is whether a thing half-made is a failure or just patient."
[A] "Patient. Like its maker." → "...Get out before I say something soft.
Come back tomorrow. Bring fang steel."
[B] "It's been dust for years. Let it go." → "Maybe. Forge's cold today."
**SCENE: "Fang Steel"** (event script `sten_fang_steel`; authored canon):
Triggers once, the next day (or later) the player is in town during the
morning blocks (6-12) after choosing [A] in Sten's L7 event "Masterwork",
carrying the Steel Sword. Camera holds on Sten at the smithy — no walking,
this one is a held shot.
Sten: "You came. Good. Bench." / "Twenty years I let judges tell me what
finished looks like." (beat) / "Watch. This part I only do once." (turns
to the forge; beat) / "Folded steel remembers every hand that failed it.
Today it gets one that didn't." / "Base is done. The edge is yours to
earn — fang, glass, coin. Forge is open when you are."
Toast: "Forging unlocked: Fangsteel Blade". Sten +50 bond; flag
`sten_masterwork_done`.
**Recipe gate:** the Fangsteel Blade upgrade (steel_sword + 5 goblin_fang
+ 2 driftglass + 2000g) stays HIDDEN in Sten's Forge list until this scene
plays — `sten_masterwork_done` is what reveals it.

---

## DOC BRAM — Clinic doctor
Dry, tired, kind underneath. Ex-city surgeon who burned out. Birthday:
**Summer 4**. **Schedule:** 6-9 clinic; 9-12 clinic; 12-17 clinic; 17-20
plaza walk; 20-2 home. Rain: clinic all day. Festival: plaza, hovering near
the food.
**Gifts:** loves carrot, frostcap; likes any crop, wildroot; dislikes
goblin_fang ("I REMOVE these from people."). **Perks:** L5 gift: 2 frostcap;
L8 gift: "house call" +20 max HP permanent (one-time, implement as
GameState.max_hp += 20 with flag).
**STRANGER:** "Clinic's open. Try not to need it." / "You're the one going
into the Delve? I'll prep a bed." / "Sleep. Water. Vegetables. That's the
whole lecture." / "Hm, farmer's hands already. Blisters heal, keep working."
**ACQUAINT:** "Your color's better than last month. Marginally." / "I've
stitched three goblin bites this season. Bring me a boring week." /
"The city had better equipment. Worse patients. Don't quote me." / "Eat the
carrots you grow. Doctor's orders, literally."
**FRIEND:** "You're my healthiest patient. That's a low bar. Still." /
"Rosa keeps sending soup for 'my patients.' I AM eating it myself, yes." /
"I don't miss the city. I miss thinking I was important. Different things." /
"Show me the arm. ...The OTHER arm. You didn't even notice this one?"
**CLOSE:** "I keep a chart on you. Professional habit. It's mostly worry
now." / "You know why I left the city? Someday I'll tell you. Not today.
The light's wrong." / "If the Delve takes you, I want it noted I objected."
**KINDRED:** "I told you why I left, once. You're the only one here who
knows. Keep being careful with it." / "Healthiest person in Emberhollow.
Official chart. Don't let it go to your head."
**Seasonal:** (Winter/FRIEND+) "Frostcap season. Nature's apology for
winter." **Rain:** "Rain means slip injuries. Walk like you have a spare
ankle. You don't."
**Birthday reaction:** "A birthday acknowledged. How clinical of you. ...
Thank you."
**Gift loved:** "Ah — actual nutrition. You listen." **liked:** "This will
do you more good than me. Take half back. ...No? Fine." **disliked:** "Why."
**HEART EVENT L3 — "Quiet Hours":** The clinic is empty. Bram is staring at
a framed city medical license. "Busiest surgeon on my floor, once. Now I
lance boils and lecture about vegetables. Some days that feels like falling."
[A] "Feels like landing, to me." → "...Huh. Landing. I'll try that word for
a while."
[B] "So go back." → "Yes. Well. Appointment's over."
**HEART EVENT L7 — "The Reason":** Dusk. Bram, unprompted: "I lost one on
the table. My error. Everyone said the numbers forgave me. Numbers do that.
I didn't. So I came here, where the stakes are boils and birthdays."
[A] "The stakes here are people. Same as there." → quiet. "...That is the
first true thing anyone's said to me in six years."
[B] "Everyone makes mistakes, forget it." → "'Forget it.' The city said
that too. Good evening."

---

## ROSA — Saloon keeper, festival organizer
Loud, warm, unstoppable. Believes the town square is the town's heart and
refuses to let it die. Birthday: **Fall 2**. **Schedule:** 6-9 plaza
(setting chairs); 9-12 saloon; 12-17 saloon; 17-20 saloon; 20-2 saloon.
Rain: saloon all day. Festival: plaza center (she runs them).
**Gifts:** loves strawberry, melon; likes corn, tomato, emberberry;
dislikes driftglass ("It's a WET ROCK, love."). **Perks:** L5 gift: 2 melon
seeds; L8 gift: "The Ember's own" recipe dialog + 250g.
**STRANGER:** "Welcome to The Ember! First smile's free." / "New face! Sit,
sit. Standing people make the room nervous." / "We pour cider and opinions.
Both strong." / "Hearthstead's heir! The plaza's been WAITING for you."
**ACQUAINT:** "The usual? You don't have a usual yet. Let's fix that." /
"Alden says festivals are 'expenditures.' I say they're the point." / "I've
seen you hauling turnips. Farmers who wave get discounts. Wave more." /
"Finn was in here doing impressions of you fighting slimes. It was AFFECTIONATE."
**FRIEND:** "There you are! The room's better with you in it." / "When the
plaza's full, this town remembers itself. That's my whole religion." /
"Sten smiled in here Tuesday. Wrote the date down." / "You fight, you farm,
you still come by. You're my favorite kind of tired."
**CLOSE:** "I planned four festivals the year everyone said this town was
done. Spite is a renewable resource, love." / "My mother ran The Ember. Her
rule: no one drinks alone, no one leaves sad. I've only ever broken it for
myself." / "You're on festival crew for life now. No, you can't resign."
**KINDRED:** "The Ember's yours as much as mine. You just don't do dishes." /
"Town's alive again. Everyone says it's the festivals. It's not, love. It's
that people watched YOU try."
**Seasonal:** (Summer/any) "Sunfire's coming! I can smell the bonfire
already. That might be the kitchen." **Rain:** "Rain! Saloon weather. The
till loves a good storm."
**Birthday reaction:** "For ME? The organizer never gets organized FOR.
You've broken something in me, love. Happily."
**Gift loved:** "LOVE. LOVE! Kitchen, now, we're celebrating." **liked:**
"Into the pot it goes. You'll taste it Friday." **disliked:** "...I'm going
to smile through this one, love."
**HEART EVENT L3 — "Empty Chairs":** Before opening, Rosa is arranging plaza
chairs for a festival, half of them empty last year. "Some years I set forty
and fill twelve. Alden thinks I don't count. I count every chair, love."
[A] "Set forty-one. I'm coming." → "One yes at a time. That's how mother
filled rooms. FORTY-ONE it is."
[B] "Maybe set twelve then." → "...Twelve. Sure. Efficient." (she sets forty
anyway, quieter)
**HEART EVENT L7 — "Mother's Rule":** Late. Rosa alone, one glass, lights
low. "'No one leaves sad.' Mother's rule. She died in the spring, the plaza
was full for her, and I poured for two hundred people and went home to none."
[A] Sit down and stay a while. → (no dialog choice text; the scene simply
holds a beat) "...Thanks, love. Rule holds. Even for me, turns out."
[B] "You're the happiest person I know." → "That's the till talking, love.
Good night."

---

## MAYOR ALDEN — Mayor, opens the game
Formal, gentle, tired hope. Watched Emberhollow shrink for thirty years.
Birthday: **Spring 6**. **Schedule:** 6-9 mayor's house porch; 9-12 plaza
notice board; 12-17 plaza/town walk; 17-20 saloon (one cider); 20-2 home.
Festival: plaza podium.
**Gifts:** loves turnip ("The first crop I ever grew, you know."); likes
any crop; dislikes wisp_dust ("Delve dust. In the STREETS?"). **Perks:** L5
gift: 100g "town gratitude fund"; L8 gift: deed dialog + plaza key line.
**INTRO (Day 1, on the farm, one-time — quest grant "New Roots"):**
"Ah — you made it. Welcome to Hearthstead. Your grandmother worked this
soil forty years; the town ate from it for most of them." / "I'll be plain:
Emberhollow is fading. Shops quiet, plaza empty, and something old has
soured in the Delve east of here." / "But a lit window on this farm is the
best news we've had in years. Meet the town — all eight of us worth
meeting, I'm afraid I'm counted. Come find me after. There's a fund." →
grants quest New Roots.
**STRANGER:** "Good day. The notice board is current — I see to it
personally." / "Eight residents, four festivals, one mayor. Modest, but
accounted for." / "Your grandmother once out-argued me at a Harvest Fair.
Twice." / "Mind the Delve, please. I sign the condolence letters."
**ACQUAINT:** "The plaza had markets every week, once. I remember the
noise. Good noise." / "Rosa calls my budgeting 'a war on joy.' I fund her
festivals anyway. Don't tell her." / "Crops from Hearthstead in Marta's
window again. People notice, you know." / "Paperwork, dear neighbor, is how
a small town says 'we intend to still exist.'"
**FRIEND:** "I walk the plaza each noon so it's never truly empty. Between
us, it's the best part of my day." / "You've met everyone now. You know
what I know: this town is eight good reasons." / "Garrick and Sten — that
feud predates my office. Even mayors don't touch it." / "The condolence
drawer has been shut all season. I credit you."
**CLOSE:** "Thirty years in office. My great act may be having handed you a
quest list." / "I drafted my resignation the winter before you came. It's
still in the drawer. It can stay there." / "When the Fair judging comes,
I am RUTHLESSLY impartial. ...Grow something orange anyway."
**KINDRED:** "I've started calling it 'the year things turned' in the town
ledger. You know which year." / "If Emberhollow has a future worth the
name, it walked in off that farm."
**Seasonal:** (Spring/any) "Sowing Festival on the 14th. Attendance is not
mandatory. Attendance is deeply hoped for." **Rain:** "Rain on the ledger
means rain in the fields means a good column of numbers. Lovely."
**Birthday reaction:** "Well. The office rarely receives, only disburses.
Thank you, truly."
**Gift loved:** "A turnip. You absolute historian. Thank you." **liked:**
"For the town table. Which is my table, but the sentiment scales." 
**disliked:** "I'll log this as... miscellaneous."
**HEART EVENT L3 — "The Ledger":** Alden at the notice board with the town
ledger. "Population column. Forty-one, then thirty, then twelve, then
eight. I keep neat books of a quiet decline. That is most of mayoring, it
turns out."
[A] "Add a line: fields at Hearthstead, replanted." → he actually writes
it. "...Unorthodox bookkeeping. I'll allow it."
[B] "Numbers are numbers." → "Quite. Neatness endures. Good day."
**HEART EVENT L7 — "The Drawer":** His porch, evening. He shows you a
yellowed envelope. "My resignation. Drafted the winter the clinic nearly
closed. I keep it to remember I chose to stay. Everyone here chose to
stay, you know. Even you."
[A] "Especially me." → "Then the drawer keeps its letter, and I keep my
town. A fine trade."
[B] "Maybe it's time to retire anyway." → "...Perhaps. The drawer will
outlast the dream, at this rate. Good evening."

---

## FINN — Beach kid (teen), dreamer
Restless, fast-talking, wants to matter. Fishes badly on purpose ("catching
means stopping"). Birthday: **Summer 17**. **Schedule:** 6-9 beach pier;
9-12 beach; 12-17 beach (rain: saloon corner); 17-20 plaza fountain edge;
20-2 home (town). Festival: wherever the food is.
**Gifts:** loves slime_gel ("It BOUNCES. It's ALIVE. It's GREAT."); likes
wisp_dust, tideshell; dislikes turnip ("Old people food, no offense to old
people or turnips."). **Perks:** L5 gift: 3 tideshell; L8 gift: "lucky
lure" trinket dialog + 150g.
**STRANGER:** "You're the farmer who FIGHTS?! Okay okay okay act normal." /
"I've seen the whole Delve. From outside. The door part." / "Shells for
sale! Not really. But LOOK at this one." / "Bet you can't hit that post
from here. Bet you CAN though, actually."
**ACQUAINT:** "Garrick says the Delve's floor two has wisps. Describe them.
Slowly." / "I'm not scared of the water, the water's scared of— okay a wave
got me earlier, don't tell Rosa." / "When I'm your age I'm gonna have a
sword AND a boat." / "Doc says I have 'energy.' He says it like a diagnosis."
**FRIEND:** "You're basically my hero, but don't let it change how you act
around me. Be exactly this cool." / "I mapped the beach. All of it. Took an
hour. The SEA though — the sea's gonna take WEEKS." / "Tell me the slime
king part again. The SLAM part." / "I put a shell on your fence post. It's
a signal. It means 'hi.'"
**CLOSE:** "Dad's boat is still in the shed. Nobody says that out loud
around here, so, now you know why the pier and me." / "If you ever go down
past floor three — take me. Not INTO it. Just... to the door. Deal?" /
"You're the only one who answers my questions like they're real questions."
**KINDRED:** "Okay so long-term plan: you farm, I sail, Emberhollow gets
famous. I've told no one else the plan. Guard it." / "Best friend. That's
just — that's just what the role's called. Deal with it."
**Seasonal:** (Summer/any) "Sunfire festival! Bonfire! Rosa lets me stack
the wood if I stop 'improving' the stack!" **Rain:** "Pier's slippery.
Which makes it BETTER, but Doc made me promise."
**Birthday reaction:** "You KNOW my birthday? This is the best day of my
ENTIRE— okay top five. TOP FIVE."
**Gift loved:** "SLIME! You get me. You completely get me." **liked:**
"Ooh, for the collection. The collection is a bucket." **disliked:**
"...I'll trade it to Marta for something with bounce."
**HEART EVENT L3 — "The Map of Everything":** Finn unrolls a hand-drawn map:
the beach in obsessive detail, the sea a huge blank with 'EVERYTHING ELSE'
written across it. "Everyone laughs at the blank part. The blank part's the
POINT."
[A] "Blank means yours." → "...yeah. YEAH. 'Blank means yours.' I'm writing
that ON it."
[B] "You should fill in what's real first." → "That's what EVERYONE—
whatever. Tide's changing."
**HEART EVENT L7 — "The Shed":** Finn, quiet for once, outside a locked
boat shed. "Dad's boat. Three years. Mom won't sell it, won't open it. I
tell everyone I fish so I have a reason to be near it. That's the whole
secret. That's all of it."
[A] "When you're ready, I'll help you open it." → "...not today. But that's
the first plan for it I've ever liked."
[B] "It's just a boat, Finn." → "Right. Just a boat. Tide's going out, you
should too."

---

## WILLOW — Riverwoods herbalist
Soft-spoken, precise, half-wild. Talks to the forest more easily than to
people; wisps don't frighten her. Birthday: **Fall 21**. **Schedule:** 6-9
Riverwoods hut; 9-12 riverbank; 12-17 forest paths; 17-20 hut; 20-2 hut.
Rain: under the hut awning, delighted. Festival: plaza, at the very edge,
leaves early... (present 10:00-15:00 only).
**Gifts:** loves wildroot, frostcap; likes emberberry, wisp_dust ("They
shed this when they're calm, you know."); dislikes iron/swords category —
use goblin_fang as the disliked concrete item ("Please bury that. It
remembers being angry."). **Perks:** L5 gift: 2 wildroot + 1 emberberry;
L8 gift: "forest-mark" dialog + 200g worth of forage bundle.
**STRANGER:** "...Oh. A person. Hello, person." / "The river's high today.
It's showing off." / "You may pick the berries. Ask the bush first. It
can't answer. Ask anyway." / "The farm woke up. The woods mentioned it."
**ACQUAINT:** "You walk quieter than you used to. The forest appreciates
it." / "Wisps aren't angry, you know. They're LOST. There's a difference." /
"I trade Doc herbs for silence. Both of us overpay happily." / "Rain is the
forest drinking. It's rude to interrupt. We can talk after."
**FRIEND:** "I saved the sunny clearing for you. I mean — it was already
there. But I THOUGHT of you." / "The Delve wasn't always sour. The roots
remember a door that sang. Roots exaggerate. ...Some." / "You fight the
forest's lost things gently. I checked. That's why we're friends." /
"Emberberries. Second-best thing in the woods. I won't say the first, it
gets vain."
**CLOSE:** "I came here after the city, like Doc. His wound has a name.
Mine is just... crowds. The trees never ask me to be loud." / "I marked
your fence line in forest-sign. It means 'kin of this ground.' The deer
will still eat your lettuce. It's not magic. It's manners." / "Take
frostcap into the Delve in winter. The dark respects what grows in cold."
**KINDRED:** "The woods count you as weather now. Reliable. Returning.
That's their highest rank. Mine too." / "When the wisps calm someday —
and they will, near you — come find me first."
**Seasonal:** (Winter/any) "Frostcap under the snow line. The forest keeps
a pantry. It shares with the polite." **Rain:** "Shhh. ...Sorry. It's
drinking. Isn't it lovely."
**Birthday reaction:** "The forest didn't tell you. So a PERSON remembered.
...I'm keeping this feeling."
**Gift loved:** "From the ground, given with hands. That's the whole
ceremony. Thank you." **liked:** "Mm. The woods approve. I concur."
**disliked:** "I'll bury it respectfully."
**HEART EVENT L3 — "The Listening":** Willow presses your hand flat to a
mossy trunk. "Wait. ...There. Sap-rise. Most people can't wait long enough
to feel it. Most people are a bit broken that way."
[A] Wait, and say nothing. → she smiles fully for the first time. "You
heard it. Now you can't unhear it. Congratulations. Condolences."
[B] "I don't feel anything." → "You didn't WAIT. ...It's fine. Not everyone
waits."
**HEART EVENT L7 — "Why the Woods":** Her hut, tea, rain outside. "The city
had a market street. Ten thousand voices. I stood in it one morning and
couldn't find mine anywhere in the noise. So I moved somewhere quiet enough
to hear it again. It took two years. It sounds like this. This exact
volume."
[A] (match her volume) "It's a good voice." → "...The forest said you'd say
that. The forest is very smug about you."
[B] "You'd get used to the noise again." → "That's what losing your voice
FEELS like, at first. More tea?"

---

## GARRICK — Retired adventurer, quest-giver
Scarred, wry, done pretending the Delve is fine. Feud with Sten (Sten made
his last sword; the sword broke; the friendship went with it). Birthday:
**Winter 15**. **Schedule:** 6-9 farm-side Delve entrance; 9-12 Delve
entrance; 12-17 saloon; 17-20 saloon; 20-2 home (town). Rain: saloon all
day. Festival: plaza, near Rosa's cider.
**Gifts:** loves goblin_fang, iron_sword-category (use melon as a joke
loved item instead — NO: keep it grounded — loves goblin_fang, emberberry
("Trail food. Good trail food.")); likes slime_gel, wisp_dust; dislikes
strawberry ("What do I look like to you?"). **Perks:** L5 gift: 2 goblin
fang; L8 gift: "old shield technique" dialog → one-time +10 max HP flag.
**QUESTS:** Q2 "Prove It" (first talk, any level): reach Delve floor 2 →
200g. Q3 "The King Below" (after Q2): defeat the Slime King → 500g
(auto-complete if flag already set: "Heard the King's already met you.
Ha! Money's still money.").
**STRANGER:** "Farmer with a blade. The Delve's eaten better. ...Prove me
wrong, actually. Please." / "Floor one's slimes. Floor two's worse. Floor
three sings. You'll see." / "I'd go myself but my knee retired before I
did." / "Watch the goblin wind-up. The tell's in the shoulders."
**ACQUAINT:** "Still standing. Good. The Delve notices persistence." /
"Dodge THROUGH the slam, not away. Rings are thinner than they look." /
"I cleared floor two the year of the long winter. Alone. Stupid. Glorious." /
"Don't ask about Sten. ...You were about to."
**FRIEND:** "You fight smarter than I did. Less shoulder, more feet. Good." /
"The King wasn't always down there. Something soured that place around when
my sword broke. I don't say that in the saloon." / "First rule of deep
floors: eat BEFORE you're hungry. RP's just courage with a number on it." /
"That shield trick of mine — remind me. When you're ready. Not yet."
**CLOSE:** "My last sword was Sten's finest. It broke mid-swing, floor
three. I said things. He said things. Twenty years of things, now." /
"You went further down than I ever did, you know that? Don't grin. Fine.
Grin." / "The knee's fake, mostly. What retired was my nerve. Delve gives
it back to me, watching you."
**KINDRED:** "I told Sten his steel saved my life for ten years before the
day it didn't. Took me twenty years and one farmer to say it. He heard me
out. So. That happened." / "Adventurer's toast: to floors below and friends
above. You're the second one."
**Seasonal:** (Winter/any) "Delve's warmer than the street in winter.
That's not a recommendation. It's just true." **Rain:** "Rain never reaches
floor two. Weather for going down, if you ask me."
**Birthday reaction:** "You track birthdays AND slime patterns. Terrifying
person. Thank you."
**Gift loved:** "Ha! Now THAT'S useful. Old habits are pleased." **liked:**
"Delve salvage. Takes me back. Mostly to bad places, but fondly."
**disliked:** "I have EXACTLY one sweet tooth and it's retired too."
**HEART EVENT L3 — "The Tell":** Garrick, at the Delve door, watching you
check your gear. "You checked your food before your blade. That's the tell
of someone who plans to come BACK. I never had it. Checked the blade first,
every time."
[A] "You came back anyway." → "Limped back. Semantics. ...Keep checking
food first, farmer."
[B] "Blade first sounds cooler." → "'Cooler.' Aye. Cool as a condolence
letter. Alden signs those, ask him."
**SCENE: "The Bench"** (event script `garrick_sten_bench`; authored canon):
Triggers once, the next morning the player enters town (9-12 block) after
choosing [A] in Garrick's L7 event. Garrick walks from the town entrance to
the smithy; camera follows, then frames both men.
Garrick: "Sten." / Sten: "Garrick." (beat) "Twenty years, and you pick a
Tuesday." / Garrick: "Blade did everything right. I didn't. Blocked the slam
you told me never to block." (beat) / Sten: "...I know. I measured the
break. Told the whole town nothing. Seemed kinder to let them blame my steel
than your knee." / Garrick: "Your steel saved my life ten years before the
day it didn't. Should have led with that." / Sten: "Hm." (turns to the
forge) "Forge is hot. Stand there and hand me things." / Garrick: "That an
apology?" / Sten: "It's a job. Take it."
Toast: "Something in Emberhollow just got quietly better." Both +50 bond;
flag `garrick_sten_reconciled`.
**Post-scene gating:** Garrick's KINDRED line "I told Sten his steel saved
my life..." only surfaces once the flag is set; Sten gains a flag-gated
CLOSE line: "Garrick's back at the bench. Hands me things wrong. It's good."

**HEART EVENT L7 — "The Broken Sword":** Saloon, late. He sets a wrapped
bundle on the table: two halves of a beautiful blade. "Sten's masterwork,
before the one he never finished. I told the whole town it failed ME.
Truth is I blocked a slam I was told never to block. Steel did everything
right. I didn't."
[A] "Twenty years is long enough. Tell HIM that." → "...Pour me one first,
then. Tomorrow. Early. Before my nerve retires again." (unlocks CLOSE line
about the reconciliation)
[B] "Why keep a broken sword?" → "Same reason the town keeps a broken
adventurer. Somebody might need the reminder. Night, farmer."

---

## Implementation notes
- All dialog above ships as DATA (see stride contract) — resolver, not
  hardcoded strings in scripts.
- Gift categories referenced (crops, materials) resolve via ItemData types;
  concrete loved/liked/disliked ids listed per NPC take precedence.
- Heart events pause the tree like menus (DialogBox with a choice row).
- Voices: Marta=brisk warmth, Sten=clipped, Bram=dry, Rosa=exuberant,
  Alden=formal-gentle, Finn=breathless, Willow=quiet-precise,
  Garrick=wry-gravel. New lines added later must match.
