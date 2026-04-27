
;; ============================================================
;; NORMATIVE CONFLICT - Agent Based Model
;; Rauhut & Winter (2011) SSR | Winter, Rauhut & Helbing (2012) SF
;; Rauhut & Winter (2017) De Gruyter
;; ============================================================

globals [
  conflict-count
  cooperation-count
  total-interactions
]

turtles-own [
  norm-type
  commitment
  effort
  my-payoff
  my-rejections
  my-cooperations
]

to setup
  clear-all
  set conflict-count 0
  set cooperation-count 0
  set total-interactions 0
  create-turtles num-agents [
    setxy random-xcor random-ycor
    set shape "person"
    set effort 1 + random-float (1 + effort-inequality * 8)
    set commitment 0.3 + random-float 0.7
    set my-payoff 0
    set my-rejections 0
    set my-cooperations 0
    assign-norm
  ]
  reset-ticks
end

to assign-norm
  ifelse random 100 < pct-equity-agents [
    set norm-type "equity"
    set color cyan
  ][
    set norm-type "equality"
    set color orange
  ]
  set size 1.5
end

to go
  if ticks >= max-ticks [ stop ]
  ask turtles [
    let partner one-of other turtles with [distance myself <= interaction-radius]
    if partner != nobody [
      play-ultimatum-game self partner
    ]
    if norm-learning? [ maybe-update-norm ]
    rt random 45 - random 45
    fd 0.3
  ]
  let max-pay max [my-payoff] of turtles
  if max-pay > 0 [
    ask turtles [ set size 0.5 + 2.0 * (my-payoff / max-pay) ]
  ]
  tick
end

to play-ultimatum-game [proposer responder]
  let ep [effort] of proposer
  let er [effort] of responder
  let joint ep + er
  let offer compute-offer proposer responder joint
  let accepted? will-accept responder offer joint
  set total-interactions total-interactions + 1
  ifelse accepted? [
    ask proposer [
      set my-payoff my-payoff + (joint - offer)
      set my-cooperations my-cooperations + 1
    ]
    ask responder [
      set my-payoff my-payoff + offer
      set my-cooperations my-cooperations + 1
    ]
    set cooperation-count cooperation-count + 1
  ][
    ask proposer [
      set my-rejections my-rejections + 1
      if punishment-on? [ set my-payoff my-payoff - punishment-cost ]
    ]
    ask responder [ set my-rejections my-rejections + 1 ]
    set conflict-count conflict-count + 1
  ]
end

to-report compute-offer [proposer responder joint]
  let er [effort] of responder
  let ep [effort] of proposer
  ifelse [norm-type] of proposer = "equity" [
    report joint * (er / (ep + er))
  ][
    report joint * 0.5
  ]
end

to-report will-accept [responder offer joint]
  let er [effort] of responder
  let ep joint - er
  let total-e ep + er
  let expected ifelse-value ([norm-type] of responder = "equity") [
    joint * (er / total-e)
  ][
    joint * 0.5
  ]
  let deviation abs(offer - expected) / joint
  let threshold tolerance-threshold * (1 - [commitment] of responder)
  report deviation <= threshold
end

to maybe-update-norm
  let neighbors-near other turtles with [distance myself <= social-radius]
  if any? neighbors-near [
    let best max-one-of neighbors-near [my-payoff]
    if [my-payoff] of best > my-payoff [
      if random-float 1 < norm-update-rate [
        set norm-type [norm-type] of best
        set commitment max list 0 (min list 1 (commitment + random-normal 0 0.05))
        update-color
      ]
    ]
  ]
end

to update-color
  ifelse norm-type = "equity" [ set color cyan ] [ set color orange ]
end

to-report pct-equity-now
  if count turtles = 0 [ report 0 ]
  report 100 * count turtles with [norm-type = "equity"] / count turtles
end

to-report conflict-rate
  if total-interactions = 0 [ report 0 ]
  report 100 * conflict-count / total-interactions
end

to-report cooperation-rate
  if total-interactions = 0 [ report 0 ]
  report 100 * cooperation-count / total-interactions
end

to-report avg-payoff-equity
  if not any? turtles with [norm-type = "equity"] [ report 0 ]
  report mean [my-payoff] of turtles with [norm-type = "equity"]
end

to-report avg-payoff-equality
  if not any? turtles with [norm-type = "equality"] [ report 0 ]
  report mean [my-payoff] of turtles with [norm-type = "equality"]
end

@#$#@#$#@
GRAPHICS-WINDOW
210
10
648
449
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
15
15
90
48
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
95
15
170
48
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
60
205
93
num-agents
num-agents
10
200
100.0
10
1
NIL
HORIZONTAL

SLIDER
15
100
205
133
pct-equity-agents
pct-equity-agents
0
100
50.0
5
1
%
HORIZONTAL

SLIDER
15
140
205
173
effort-inequality
effort-inequality
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
15
180
205
213
interaction-radius
interaction-radius
1
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
15
220
205
253
tolerance-threshold
tolerance-threshold
0
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
15
260
205
293
norm-update-rate
norm-update-rate
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
15
300
205
333
social-radius
social-radius
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
340
205
373
punishment-cost
punishment-cost
0
5
1.0
0.5
1
NIL
HORIZONTAL

SLIDER
15
380
205
413
max-ticks
max-ticks
100
5000
1000.0
100
1
NIL
HORIZONTAL

SWITCH
15
430
205
463
norm-learning?
norm-learning?
0
1
-1000

SWITCH
15
470
205
503
punishment-on?
punishment-on?
1
1
-1000

MONITOR
660
10
830
55
% Equity Agents
pct-equity-now
1
1
11

MONITOR
660
60
830
105
Conflict Rate (%)
conflict-rate
1
1
11

MONITOR
660
110
830
155
Cooperation Rate (%)
cooperation-rate
1
1
11

MONITOR
660
160
830
205
Avg Payoff Equity
avg-payoff-equity
2
1
11

MONITOR
660
210
830
255
Avg Payoff Equality
avg-payoff-equality
2
1
11

PLOT
660
260
1000
430
Norm Distribution
ticks
% agents
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"equity" 1.0 0 -11221820 true "" "plot pct-equity-now"
"equality" 1.0 0 -955883 true "" "plot 100 - pct-equity-now"

PLOT
660
440
1000
600
Conflict and Cooperation
ticks
%
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"conflict" 1.0 0 -2674135 true "" "plot conflict-rate"
"cooperation" 1.0 0 -13840069 true "" "plot cooperation-rate"

PLOT
660
610
1000
760
Avg Payoff by Norm
ticks
payoff
0.0
100.0
0.0
10.0
true
true
"" ""
PENS
"equity" 1.0 0 -11221820 true "" "plot avg-payoff-equity"
"equality" 1.0 0 -955883 true "" "plot avg-payoff-equality"

@#$#@#$#@
## NORMATIVE CONFLICT

Agent-based model of equity vs. equality norms in the Ultimatum Game.

**Cyan agents** follow an equity norm (distribute proportional to effort).
**Orange agents** follow an equality norm (always 50/50).

### Key Parameters
- `pct-equity-agents` share of equity-norm agents
- `effort-inequality` heterogeneity of contributions
- `tolerance-threshold` base tolerance for deviating offers
- `norm-learning?` enable replicator dynamics
- `punishment-on?` enable punishment of rejected proposers

### References
Rauhut and Winter (2011) Social Science Research
Winter, Rauhut and Helbing (2012) Social Forces
Rauhut and Winter (2017) De Gruyter

@#$#@#$#@

@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@

@#$#@#$#@

@#$#@#$#@

@#$#@#$#@

@#$#@#$#@

@#$#@#$#@

@#$#@#$#@
