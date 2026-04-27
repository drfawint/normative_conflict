;; ============================================================
;; NORMATIVE CONFLICT – Agent Based Model
;; ============================================================
;;
;; Based on:
;;   Rauhut & Winter (2011): Social Science Research 40, 900-915
;;   Winter, Rauhut & Helbing (2012): Social Forces 90(3), 869-894
;;   Rauhut & Winter (2017): De Gruyter (types of normative conflict)
;;
;; SETUP:
;;   Agents are placed randomly on a grid. Each agent holds either
;;   an EQUITY norm (each player should receive proportional to their
;;   effort) or an EQUALITY norm (each player should receive 50/50).
;;   Agents also have a COMMITMENT level [0,1] (how strongly they
;;   adhere to their norm) and an EFFORT level [1,10].
;;
;; INTERACTION (Ultimatum Game):
;;   Two agents form a dyad. They share a joint account = sum of efforts.
;;   - Proposer makes an offer (how much the responder gets)
;;     based on their own norm.
;;   - Responder accepts or rejects based on their own norm
;;     and commitment level.
;;   - If accepted: both earn their share.
;;   - If rejected: both earn 0 (normative conflict).
;;   - Optional punishment: rejected proposer loses additional payoff.
;;
;; NORM LEARNING (Replicator Dynamics):
;;   Agents copy the norm of better-performing neighbours with
;;   probability = norm-update-rate.
;;
;; KEY HYPOTHESES (Rauhut & Winter):
;;   H1: More normative conflicts when effort inequality is high.
;;   H2: Punishment is only effective when norms are homogeneous.
;;   H3: With norm learning, one norm eventually dominates.
;; ============================================================

globals [
  conflict-count       ;; total rejected interactions
  cooperation-count    ;; total accepted interactions
  total-interactions   ;; all interactions so far
]

turtles-own [
  norm-type        ;; "equity" or "equality"
  commitment       ;; norm adherence strength [0,1]
  effort           ;; contribution to joint account [1,10]
  my-payoff        ;; accumulated payoff
  my-rejections    ;; number of times an offer was rejected
  my-cooperations  ;; number of times an offer was accepted
]


;; ============================================================
;; SETUP
;; ============================================================

to setup
  clear-all
  set conflict-count 0
  set cooperation-count 0
  set total-interactions 0

  create-turtles num-agents [
    setxy random-xcor random-ycor
    set shape "person"

    ;; Effort: equal (effort-inequality = 0) or heterogeneous (> 0)
    ifelse effort-inequality > 0 [
      set effort 1 + random-float (effort-inequality * 9)
    ][
      set effort 5
    ]

    set commitment 0.3 + random-float 0.7
    set my-payoff 0
    set my-rejections 0
    set my-cooperations 0

    assign-norm
  ]

  reset-ticks
end

to assign-norm
  ;; Assign norm based on slider; colour codes norm type visually
  ifelse random 100 < pct-equity-agents [
    set norm-type "equity"
    set color cyan       ;; cyan = equity agents
  ][
    set norm-type "equality"
    set color orange     ;; orange = equality agents
  ]
  set size 1.5
end


;; ============================================================
;; GO
;; ============================================================

to go
  if ticks >= max-ticks [ stop ]

  ask turtles [
    ;; Find a random partner in neighbourhood
    let partner one-of other turtles with [distance myself <= interaction-radius]
    if partner != nobody [
      play-ultimatum-game self partner
    ]

    ;; Norm learning via replicator dynamics
    if norm-learning? [ maybe-update-norm ]

    ;; Random walk
    rt random 45 - random 45
    fd 0.3
  ]

  ;; Scale agent size to payoff (visual feedback)
  let max-pay max [my-payoff] of turtles
  if max-pay > 0 [
    ask turtles [ set size 0.5 + 2.0 * (my-payoff / max-pay) ]
  ]

  tick
end


;; ============================================================
;; ULTIMATUM GAME
;; ============================================================

to play-ultimatum-game [proposer responder]
  let ep [effort] of proposer
  let er [effort] of responder
  let joint ep + er

  ;; Proposer formulates offer based on own norm
  let offer compute-offer proposer responder joint

  ;; Responder decides based on own norm and commitment
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
    ;; Normative conflict: both earn 0; proposer may be punished
    ask proposer [
      set my-rejections my-rejections + 1
      if punishment-on? [ set my-payoff my-payoff - punishment-cost ]
    ]
    ask responder [
      set my-rejections my-rejections + 1
    ]
    set conflict-count conflict-count + 1
  ]
end

to-report compute-offer [proposer responder joint]
  ;; How much does the proposer offer to the responder?
  let er [effort] of responder
  let ep [effort] of proposer
  ifelse [norm-type] of proposer = "equity" [
    ;; Equity: responder gets their proportional share of joint account
    report joint * (er / (ep + er))
  ][
    ;; Equality: always split 50/50
    report joint * 0.5
  ]
end

to-report will-accept [responder offer joint]
  ;; What does the responder expect according to their norm?
  let er [effort] of responder
  let ep joint - er   ;; infer proposer's effort (joint = ep + er)

  let expected ifelse-value ([norm-type] of responder = "equity") [
    joint * (er / (ep + er))   ;; expect proportional share
  ][
    joint * 0.5                ;; expect 50/50
  ]

  ;; Deviation from normative expectation (relative)
  let deviation abs(offer - expected) / joint

  ;; Threshold: high commitment → low tolerance → more rejections
  let threshold tolerance-threshold * (1 - [commitment] of responder)
  report deviation <= threshold
end


;; ============================================================
;; NORM LEARNING – REPLICATOR DYNAMICS
;; ============================================================

to maybe-update-norm
  let neighbors-near other turtles with [distance myself <= social-radius]
  if any? neighbors-near [
    let best max-one-of neighbors-near [my-payoff]
    if [my-payoff] of best > my-payoff [
      if random-float 1 < norm-update-rate [
        ;; Copy the norm of the most successful neighbour
        set norm-type [norm-type] of best
        ;; Small random perturbation of commitment
        set commitment commitment + random-normal 0 0.05
        set commitment max list 0 (min list 1 commitment)
        update-color
      ]
    ]
  ]
end

to update-color
  ifelse norm-type = "equity" [ set color cyan ] [ set color orange ]
end


;; ============================================================
;; REPORTERS  (for monitors and plots)
;; ============================================================

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
Avg Payoff – Equity
avg-payoff-equity
2
1
11

MONITOR
660
210
830
255
Avg Payoff – Equality
avg-payoff-equality
2
1
11

MONITOR
660
260
830
305
Total Interactions
total-interactions
0
1
11

PLOT
660
315
1000
490
Norm Distribution over Time
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
"equity (cyan)" 1.0 0 -11221820 true "" "plot pct-equity-now"
"equality (orange)" 1.0 0 -955883 true "" "plot 100 - pct-equity-now"

PLOT
660
500
1000
650
Conflict & Cooperation Rate
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
"conflict rate" 1.0 0 -2674135 true "" "plot conflict-rate"
"cooperation rate" 1.0 0 -13840069 true "" "plot cooperation-rate"

PLOT
660
660
1000
810
Avg Payoff by Norm Type
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
## NORMATIVE CONFLICT – Agent Based Model

**Based on:**
- Rauhut & Winter (2011), *Social Science Research* 40: 900–915
- Winter, Rauhut & Helbing (2012), *Social Forces* 90(3): 869–894
- Rauhut & Winter (2017), De Gruyter

---

### What this model does

Agents interact via a **Ultimatum Game** with heterogeneous effort contributions. Each agent adheres to either an **equity norm** (distribute proportional to effort) or an **equality norm** (always 50/50). When proposer and responder hold different norms, a **normative conflict** arises and both earn zero.

---

### Parameters

| Parameter | Description |
|---|---|
| `num-agents` | Number of agents |
| `pct-equity-agents` | Share of equity-norm agents (%) |
| `effort-inequality` | Degree of effort heterogeneity (0 = all equal) |
| `interaction-radius` | Spatial radius for finding a partner |
| `tolerance-threshold` | Base tolerance for deviating offers |
| `norm-update-rate` | Speed of norm copying (replicator dynamics) |
| `social-radius` | Neighbourhood for norm learning |
| `punishment-cost` | Cost imposed on rejected proposer |
| `max-ticks` | Simulation length |
| `norm-learning?` | Enable/disable replicator dynamics |
| `punishment-on?` | Enable/disable punishment of rejected proposers |

---

### Agent colours
- **Cyan** = Equity-norm agents
- **Orange** = Equality-norm agents
- **Size** scales with accumulated payoff

---

### Key Hypotheses to test
1. Higher `effort-inequality` → more normative conflicts (conflict rate ↑)
2. `punishment-on?` only effective when norm population is homogeneous
3. With `norm-learning?` enabled, one norm eventually dominates
4. Mixed-norm populations: more content conflicts than commitment conflicts

---

### Suggested Experiments (BehaviorSpace)
- Vary `pct-equity-agents` from 0–100; measure conflict rate at tick 1000
- Vary `effort-inequality` from 0–1; compare with homogeneous norms
- Test `punishment-on?` × norm homogeneity interaction
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
