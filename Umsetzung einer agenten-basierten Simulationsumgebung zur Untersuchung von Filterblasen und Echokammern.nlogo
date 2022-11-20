extensions [table]
;;"Klassen"
breed [guys guy]
breed [information info]
undirected-link-breed [friendships friendship]
undirected-link-breed [clustering cluster]
undirected-link-breed [knowledge known]
directed-link-breed [sourcefriends sourcefriend]
directed-link-breed [sourceknowledge sourceknown]

;;Variablen der jeweiligen "Klassen"
sourceknowledge-own [informationAttitude]
sourcefriends-own [weight]
guys-own [agentmemory latitude numberoffriends clusternumber]
globals[agent1 agent1copy agent2 agent2copy data datacopy counter index clusternr mojenatable zuweisung mittelwert abweichung mojena starting-seed elbow elbowlength]

;;Kern des Programms
;;Aufbau der Welt
to setup
  clear-all
  set starting-seed new-seed ;;der Wert starting-seed enthält einen zufällig generierten Seed
  output-print word "Seed für diesen Durchlauf: " starting-seed
  random-seed starting-seed  ;;hier den seed eintragen, indem "starting-seed" ersetzt wird. Bleibt dies unverändert, wird der zufällig generierte Seed verwendet.
  create-guys agentnumber [konstruktorGuy]  ;;es werden agentnumber viele Agenten erschaffen, die alle ihren Konstruktor mit der Funktion konstruktorGuy aufrufen
  create-information initialInformation * agentnumber [konstruktorInfo]  ;;es werden Informationen erschaffen, die alle ihren Konstruktor mit der Funktion konstruktorInfo aufrufen. initialInformation * agentnumber berechnet die Anzahl zu generierender Informationen
  ;;Initialisierung der globalen Variablen
  set agent1 table:make
  set agent1copy table:make
  set agent2 table:make
  set agent2copy table:make
  set data table:make
  set datacopy table:make
  set mojenatable table:make
  set counter 0
  set index 0
  set zuweisung 1
  set clusternr agentnumber
  set elbowlength 0
  set elbownumber 0
  reset-ticks
end

;;Angaben, was während des Durchlaufs passieren soll
to go
  while[ticks < 8760][ ;;diese Schleife gibt an, wer welche Aktion in jedem einzelnen Zeitschritt ausführt
    ask friendships [hide-link] ;;mit hide-link werden regelmäßig die Freundschaften zw. Personen ausgeblendet, um die Welt übersichtlicher zu halten
    ask sourcefriends [hide-link]
    create-information 1 [konstruktorInfo] ;;in jedem Zeitschrit wird eine neue Information an zufälliger Position erzeugt
    ask guys [
      ifelse algorithmicFriends = true and ticks > 360 and ticks mod 28 = 0[
        algorithmicFriendshipRecommendation
      ][
        addFriend one-of guys
      ]
      addKnowledge one-of information
    ]
    if ticks mod 56 = 0 and informationRemoval = true[
      ifelse sourcecredibility = true[
        ask information with [count sourceknown-neighbors = 0][die]
      ][
        ask information with [count known-neighbors = 0][die]
      ]
    ]
    if ticks mod 8 = 0 and sharing = true[
      ask guys[
        ifelse sourcecredibility = true[
          shareInformation one-of [sourcefriend-neighbors] of self
        ][
          shareInformation one-of [friendship-neighbors] of self
        ]
      ]
    ]
    if ticks > 360 and ticks mod 8 = 0 and algorithmicRecommendation = true[
      ask guys[
        algorithmicInformationRecommendation
      ]
    ]
    tick
  ]
  ;;nachdem alle Zeitschritte durchlaufen wurden, folgt die Clusteranalyse. Die Personen müssen dabei zuerst links zueinander herstellen, die als Grundlage für die Clusteranalyse dienen
  ask guys[
    initializeCluster
  ]
  ask guys[
    clusteranalyse
  ]
  ;;Initialisieren und befüllen des Graphen für das Ablesen des Elbow-Kriteriums
  set elbow table:length mojenatable
  set-current-plot "Ellbogen"
  setup-plots
  while[elbowlength <= elbow][
    update-plots
    set elbowlength elbowlength + 1
  ]
  getMathValues
  TestOfMojena  ;;Ausführen des Test von Mojena
end

;;"Konstruktor" der Agenten
to konstruktorGuy
  setxy random-xcor random-ycor ;;Der Person werden zufällige Starkoordinaten zugewiesen
  set color 125
  set agentmemory memory ;;Bestimmt die Anzahl an Informationen, die ein Agent maximal besitzen kann, Wert entspricht dem Schieberegler
  set numberoffriends potentialFriends ;;Bestimmt die maximal mögliche Anzahl an Freunden basierend auf dem Schieberegler
  set latitude acceptanceLatitude  ;;Bestimmt die Latitude of Acceptance basierend auf dem Schieberegler
end

to konstruktorInfo
  setxy random-xcor random-ycor ;;Der Information werden zufällige Startkoordinaten zugewiesen
  set shape "circle"
  set color 95
end

;;einzelne aufrufbare Funktionen
to addKnowledge [newinfo]
  ;;Koordinaten der Information mit Koordinaten des Agenten inkl. Latitude of Acceptance abgleichen
  ifelse sourcecredibility = true[ ;;Unterteilung, ob Sourcecrdibility aktiviert ist, oder nicht. Dann jeweils eine weitere Unterteilung, ob die Latitude of Acceptance als fester Wert oder Funktion betrachtet wird
    let exponent random 2  ;;random X gibt eine zufällige Zahl aus, die im Bereich 0 <= Zufallszahl < X liegt
    let a random-float 1 * (-1 ^ exponent) ;;random-float gibt eine zufällige Gleitkommazahl an, die zwischen 0 und 1 liegt
    ifelse latitudeFunction = true[
      if random-float 1 < integration-probability distance newinfo[
        ifelse (count sourceknown-neighbors) < agentmemory[    ;;Überprüfung, ob das Gedächtnis des Agenten bereits voll ist
          create-sourceknown-to newinfo [set informationAttitude a]
          ask knowledge [set color 65]
          setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)  ;;setxy in Kombination mit mean wird je genutzt, um die Position der Person über die durchschnittlichen Koordinaten der integrierten Informationen anzupassen
        ][
          ask one-of my-out-sourceknowledge [die]  ;;Löschen einer zufälligen integrierten Information (bei vollem Gedächtnis)
          create-sourceknown-to newinfo [set informationAttitude a]
          ask knowledge [set color 65]
          setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
        ]
        ;;Chance von ausgewählter Prozentzahl, eine gerade integrierte Funktion direkt zu teilen
        if sharing = true and random-float 1 <= chanceToShare and count sourcefriend-neighbors > 0[
          ask one-of [sourcefriend-neighbors] of self [addKnowledgeSrcCred newinfo a myself]
        ]
      ]
    ][
      let infox [xcor] of newinfo
      let infoy [ycor] of newinfo
      if (abs(xcor - infox) < latitude) and (abs(ycor - infoy) < latitude) [
        ifelse (count sourceknown-neighbors) < agentmemory[
          create-sourceknown-to newinfo [set informationAttitude a]
          ask knowledge [set color 65]
          setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
        ][
          ask one-of my-out-sourceknowledge [die]
          create-sourceknown-to newinfo [set informationAttitude a]
          ask knowledge [set color 65]
          setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
        ]
        if sharing = true and random-float 1 <= chanceToShare and count sourcefriend-neighbors > 0[
          ask one-of [sourcefriend-neighbors] of self [addKnowledgeSrcCred newinfo a myself]
        ]
      ]
    ]
  ][
    ifelse latitudeFunction = true[  ;;Umsetzung der Integration von Informationen, wenn die latitude of acceptance als Funktion dargestellt wird
      let dist integration-probability distance newinfo  ;;Aufrufen der von Geschke et al. (2019) definierten Funktion zur Berechnung der Integrationswahrscheinlichkeit. Dabei wird die Distanz zur jeweiligen Information als Parameter übergeben
      if random-float 1 < dist[
        ifelse (count known-neighbors) < agentmemory
        [
          create-known-with newinfo
          ask knowledge [set color 65]
          setxy (mean [xcor] of known-neighbors) (mean [ycor] of known-neighbors)
        ]
        [
          ask one-of my-knowledge [die]
          create-known-with newinfo
          ask knowledge [set color 65]
          setxy (mean [xcor] of known-neighbors) (mean [ycor] of known-neighbors)
        ]
        if sharing = true and random-float 1 <= chanceToShare and count friendship-neighbors > 0[
          ask one-of [friendship-neighbors] of self [addKnowledge newinfo]
        ]
      ]
    ][
      let infox [xcor] of newinfo
      let infoy [ycor] of newinfo
      if (abs(xcor - infox) < latitude) and (abs(ycor - infoy) < latitude) [
        ifelse (count known-neighbors) < agentmemory
        [
          create-known-with newinfo
          ask knowledge [set color 65]
          setxy (mean [xcor] of known-neighbors) (mean [ycor] of known-neighbors)
        ]
        [
          ask one-of my-knowledge [die]
          create-known-with newinfo
          ask knowledge [set color 65]
          setxy (mean [xcor] of known-neighbors) (mean [ycor] of known-neighbors)
        ]
        if sharing = true and random-float 1 <= chanceToShare and count friendship-neighbors > 0[
          ask one-of [friendship-neighbors] of self [addKnowledge newinfo]
        ]
      ]
    ]
  ]
end

to addKnowledgeSrcCred [newinfo m source]  ;;Hinzufügen von Informationen, wenn Sourcecrdibility betrachtet wird. Diese Funktion wird benutzt, wenn Inhalte geteilt werden
  if count sourcefriend-neighbors > 0 and sourcefriend-neighbor? source = true[  ;;Prüfen, ob der aufrufende Agent Freunde hat und der Sender des geteilten Inhalts einer von diesen ist
    let a 0
    ifelse out-sourceknown-neighbor? newinfo = true[
      set a [informationAttitude] of out-sourceknown-to newinfo  ;;setzt a auf den Wert der Einstellung zur Information, falls diese bereits integriert ist
    ][
      let exponent random 2
      set a random-float 1 * (-1 ^ exponent) ;;falls die Information noch nicht integriert wurde, wird hier die Einstellung zu dieser als zufällige Zahl zwischen -1 und 1 berechnet
    ]
    let beta 0.5
    let s [weight] of out-sourcefriend-to source  ;;s spiegelt die Einstellung zu dem Agenten dar, der die Information geteilt hat ("source")
    let polarityModifier 1 / (1 + (s ^ 2))
    let am a * m
    let sourceChange polarityModifier * ((beta / sqrt (1 + (am ^ 2))) * am)
    let attitudeChange s * m
    let x s - 0.5
    let templat [latitude] of self + x   ;;temporäre Variable, um die latitude of acceptance des Agenten nicht permanent, sondern temporär zu ändern (nur während der Bewertung der geteilten erhaltenen Information)
    set s s + sourceChange
    (ifelse s < 0[
      set s 0
    ]s > 1[
      set s 1
    ])
    ask out-sourcefriend-to source [set weight s] ;;Anpassen des Vertrauens bzw. Misstrauens gegenüber der Quelle
    let me a + attitudeChange
    (ifelse me < -1[  ;;Limitierung der Werte für Einstellungen bzgl. Informationen, damit diese im Wertebereich [-1, 1] bleiben
      set me -1
    ]me > 1[
      set me 1
    ])
    ifelse out-sourceknown-neighbor? newinfo = true[
      ask out-sourceknown-to newinfo[set informationAttitude me] ;;Ändern der Einstellung zur der geteilten Information, wenn diese bereits integriert war. Dies spiegelt eine Bestärkung oder Abschwächung der Ansicht durch die Ansichten der Quelle wider
    ][
      ifelse latitudeFunction = true[  ;;ab hier wie gehabt das Integrieren der Information, wobei die Einstellung zu dieser auf dem berechneten Wert basiert
        let dist integration-probability ((distance newinfo) - x)
        if random-float 1 < dist[
          ifelse (count sourceknown-neighbors) < agentmemory
          [
            create-sourceknown-to newinfo [set informationAttitude me]
            ask knowledge [set color 65]
            setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
          ]
          [
            ask one-of my-sourceknowledge [die]
            create-sourceknown-to newinfo [set informationAttitude me]
            ask sourceknowledge [set color 65]
            setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
          ]
          ;;einstellbare Wahrscheinlichkeit, eine gerade integrierte Funktion direkt zu teilen
          if sharing = true and random-float 1 <= chanceToShare and count sourcefriend-neighbors > 0[
            ask one-of [sourcefriend-neighbors] of self [addKnowledgeSrcCred newinfo me myself]
          ]
        ]
      ][
        let infox [xcor] of newinfo
        let infoy [ycor] of newinfo
        if (abs(xcor - infox) < templat) and (abs(ycor - infoy) < templat) [
          ifelse (count sourceknown-neighbors) < agentmemory
          [
            create-sourceknown-to newinfo [set informationAttitude me]
            ask knowledge [set color 65]
            setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
          ]
          [
            ask one-of my-sourceknowledge [die]
            create-sourceknown-to newinfo [set informationAttitude me]
            ask sourceknowledge [set color 65]
            setxy (mean [xcor] of sourceknown-neighbors) (mean [ycor] of sourceknown-neighbors)
          ]
          ;;einstellbare Wahrscheinlichkeit, eine gerade integrierte Funktion direkt zu teilen
          if sharing = true and random-float 1 <= chanceToShare and count sourcefriend-neighbors > 0[
            ask one-of [sourcefriend-neighbors] of self [addKnowledgeSrcCred newinfo me myself]
          ]
        ]
      ]
    ]
  ]
end

to shareInformation [anotherguy]  ;;Funktion zum Teilen von Inhalten
  ifelse sourcecredibility = true[
    if count sourcefriend-neighbors > 0[
      if sharing = true and anotherguy != self and in-sourcefriend-neighbor? anotherguy = true and count sourceknown-neighbors > 0[  ;;jeweils die Überprüfung, ob nicht versucht wird, mit sich selbst zu teilen und ob der Agent, mit dem geteilt werden soll, ein Freund ist
        let message one-of [sourceknown-neighbors] of self
        let m [informationAttitude] of out-sourceknown-to message ;;Einstellung zur Information wird als Einstellung der Nachricht übermittelt
        ask anotherguy[addKnowledgeSrcCred message m myself]
      ]
    ]
  ][
    if count friendship-neighbors > 0[
      if sharing = true and anotherguy != self and friendship-neighbor? anotherguy = true and count known-neighbors > 0[
        ask anotherguy[addKnowledge one-of [known-neighbors] of myself]
      ]
    ]
  ]

end

to addFriend [anotherguy] ;;Hinzufügen von Freunden. Selbstbefreundung ausgeschlossen. Überprüfung, dass jeder Agent nur die vorgegebene Anzahl an max. Freunden hat. Unterteilung in alle möglichen Kombinationen von Parametern, die Einfluss auf die Befreundung haben
  (ifelse sourcecredibility = true and latitudeFunction = true[
    let otherFriends [sourcefriend-neighbors] of anotherguy
    if anotherguy != self and count out-sourcefriend-neighbors < numberoffriends and count otherFriends < numberoffriends and euclidDistance anotherguy < integration-probability distance anotherguy[
      create-sourcefriend-to anotherguy [set weight 0.5]  ;;initiales Vertrauen zwischen Agenten wird jeweils auf 0.5 gesetzt
      create-sourcefriend-from anotherguy [set weight 0.5]
      ask sourcefriends [set color 15]
    ]
  ]sourcecredibility = true and latitudeFunction = false[
    let otherFriends [sourcefriend-neighbors] of anotherguy
    if anotherguy != self and count out-sourcefriend-neighbors < numberoffriends and count otherFriends < numberoffriends and euclidDistance anotherguy < [latitude] of self[
      create-sourcefriend-to anotherguy [set weight 0.5]
      create-sourcefriend-from anotherguy [set weight 0.5]
      ask sourcefriends [set color 15]
    ]
  ]sourcecredibility = false and latitudeFunction = true[
    let otherFriends [friendship-neighbors] of anotherguy
    if anotherguy != self and count friendship-neighbors < numberoffriends and count otherFriends < numberoffriends and euclidDistance anotherguy < integration-probability distance anotherguy[
      create-friendship-with anotherguy
      ask friendships [set color 15]
    ]
  ][
    let otherFriends [friendship-neighbors] of anotherguy
    if anotherguy != self and count friendship-neighbors < numberoffriends and count otherFriends < numberoffriends and euclidDistance anotherguy < [latitude] of self[
      create-friendship-with anotherguy
      ask friendships [set color 15]
    ]
  ])
end

to reevaluateFriends  ;;Funktion zum Überprüfen von Freunden, sodass Freunde, die zu weit entfernt sind, entfernt werden.
  (ifelse sourcecredibility = true and latitudeFunction = true[  ;;Unterteilung in alle möglichen Kombinationen von Parametern, die Einfluss auf die Befreundung haben
    if count my-out-sourcefriends > 0[
      foreach sort my-out-sourcefriends[  ;;Durchlaufen alle Freunde
        i ->
        let s [weight] of i ;;Überprüfen der Einstellung zu dem Freund, um die latitude of acceptance anzupassen
        let x 0
        (ifelse s < 0.5[
          set s 0.5 - s
          set x -1 * s
        ]s > 0.5[
          set x s
        ])
        let a [end2] of i
        if euclidDistance a > integration-probability ((distance a) - x)[
          ask out-sourcefriend-to a [die]
          ask in-sourcefriend-from a [die]
        ]
      ]
    ]
  ]sourcecredibility = true and latitudeFunction = false[
    if count my-out-sourcefriends > 0[
      foreach sort my-out-sourcefriends[
        i ->
        let s [weight] of i
        let x 0
        (ifelse s < 0.5[
          set s 0.5 - s
          set x -1 * s
        ]s > 0.5[
          set x s
        ])
        let a [end2] of i
        if euclidDistance a > ([latitude] of self + x)[
          ask out-sourcefriend-to a [die]
          ask in-sourcefriend-from a [die]
        ]
      ]
    ]
  ]sourcecredibility = false and latitudeFunction = true[
    if count friendship-neighbors > 0[
      foreach sort friendship-neighbors[
        i -> if euclidDistance i > integration-probability distance i[
          ask friendship-with i [die]
        ]
      ]
    ]
  ][
    if count friendship-neighbors > 0[
      foreach sort friendship-neighbors[
        i -> if euclidDistance i > [latitude] of self[
          ask friendship-with i [die]
        ]
      ]
    ]
  ])
end

to algorithmicInformationRecommendation
  ;;Recommender Systems für algorithmische Empfehlung
  if algorithmicRecommendation = true[
    ifelse sourcecredibility = true[
      (ifelse collaborative = true[
      ;;Kollaborative Empfehlungen, d.h. Empfehlungen basierend auf als ähnlich angesehenen Benutzern
      ;;Empfehlung einer integrierten Information des als am ähnlichsten angesehenen Benutzers
        let temp 0
        let distanz 999
        foreach sort guys[ ;;Durchlaufen aller Personen
          i -> if i != self and euclidDistance i < distanz and count [out-sourceknown-neighbors] of i > 0[ ;;Suche nach der ähnlichsten Person, d.h. der Person, zu der die euklidische Distanz am geringsten ist
            set distanz euclidDistance i
            set temp i
          ]
        ]
        if temp != 0[
          addKnowledge one-of [sourceknown-neighbors] of temp
        ]
      ]contentBased = true[
      ;;Inhaltsabsierte Empfehlungen, d.h. Empfehlungen basierend auf als ähnlich angesehenen Inhalten (d.h. Wissen/ Ansichten)
      ;;Empfehlung der als am ähnlichsten angesehenen, noch nicht integrierten Information
        let temp 0
        let distanz 999
        foreach sort information[ ;;Durchlaufen aller Informationen
          i -> if sourceknown-neighbor? i = false and euclidDistance i < distanz[ ;;Suche nach der ähnlichsten Information, d.h. der Information, zu der die euklidische Distanz am geringsten ist
            set distanz euclidDistance i
            set temp i
          ]
        ]
        if temp != 0[
          addKnowledge temp
        ]
      ])
    ][
      (ifelse collaborative = true[
      ;;Kollaborative Empfehlungen, d.h. Empfehlungen basierend auf als ähnlich angesehenen Benutzern
      ;;Empfehlung einer integrierten Information des als am ähnlichsten angesehenen Benutzers
        let temp 0
        let distanz 9999
        foreach sort guys[
          i -> if i != self and euclidDistance i < distanz and count [known-neighbors] of i > 0[
            set distanz euclidDistance i
            set temp i
          ]
        ]
        if temp != 0[
          addKnowledge one-of [known-neighbors] of temp
        ]
      ]contentBased = true[
      ;;Inhaltsabsierte Empfehlungen, d.h. Empfehlungen basierend auf als ähnlich angesehenen Inhalten (d.h. Wissen/ Ansichten)
      ;;Empfehlung der als am ähnlichsten angesehenen, noch nicht integrierten Information
        let temp 0
        let distanz 9999
        foreach sort information[
          i -> if known-neighbor? i = false and euclidDistance i < distanz[
            set distanz euclidDistance i
            set temp i
          ]
        ]
        if temp != 0[
          addKnowledge temp
        ]
      ])
    ]
  ]
end

to algorithmicFriendshipRecommendation ;;potenzielle Empfehlung von Freunden eines Freundes
  if count friendship-neighbors > numberoffriends[  ;;Zufälliges Entfernen von Freunden, sollte die maximale Anzahl bereits erreicht sein
    ask one-of friendship-neighbors[die]
  ]
  if algorithmicFriends = true[
    ;; i ist der Agent selbst, j jeweils der in Frage kommende Freund eines Freundes
    let current 0
    let potentialFriend 0
    ifelse sourcecredibility = true[
      foreach sort [out-sourcefriend-neighbors] of self[
        i -> foreach sort [out-sourcefriend-neighbors] of i[  ;;verschachtelte Schleife um die Freunde der eigenen Freunde zu durchlaufen
          j -> if jaccardPredict self j > current and j != self and out-sourcefriend-neighbor? j = false[
            set current jaccardPredict self j  ;;Aufruf der Funktion zum Berechnen des Jaccard-Koeffizienten
            set potentialFriend j
          ]
        ]
      ]
    ][
      foreach sort [friendship-neighbors] of self[
        i -> foreach sort [friendship-neighbors] of i[
          j -> if jaccardPredict self j > current and j != self and friendship-neighbor? j = false[
            set current jaccardPredict self j
            set potentialFriend j
          ]
        ]
      ]
    ]
    if potentialFriend != 0[
      addFriend potentialFriend
    ]
  ]
end

to-report jaccardPredict [i j]  ;;Berechnung des Jaccard-Koeffizienten. to-report gibt an, dass diese Funktion einen Rückgabewert besitzt
  let result 0
  ifelse sourcecredibility = true[
    let agentset1 [out-sourcefriend-neighbors] of i
    let agentset2 [out-sourcefriend-neighbors] of j
    let top count agentset1 with [out-sourcefriend-neighbor? j = true]
    let bot top + (count agentset1 with [out-sourcefriend-neighbor? j = false] + count agentset2 with [out-sourcefriend-neighbor? i = false])
    set result top / bot
  ][
    let agentset1 [friendship-neighbors] of i
    let agentset2 [friendship-neighbors] of j
    let top count agentset1 with [friendship-neighbor? j = true]
    let bot top + (count agentset1 with [friendship-neighbor? j = false] + count agentset2 with [friendship-neighbor? i = false])
    set result top / bot
  ]
  report result
end


to showFilterbubble
  let currNeighbors 0
  ifelse sourcecredibility = true[
    set currNeighbors [sourceknown-neighbors] of self
  ][
    set currNeighbors [known-neighbors] of self
  ]
  let average 0
  let agentx [xcor] of self
  let agenty [ycor] of self
  if any? currNeighbors = true [
    foreach sort currNeighbors [a ->     ;;alle integrierten Informationen durchlaufen und deren Distanz zu dem aufrufenden Agenten aufaddieren. Anschließend durch die Anzahl dieser Informationen teilen. Der Wert bildet den Radius der Filterblase
      set average (average + distance a)
    ]
    ifelse sourcecredibility = true[
      set average average / (count sourceknown-neighbors)
    ][
      set average average / (count known-neighbors)
    ]
    ;;------Hier Kreis mit Radius "average" zeichnen -------
    ;;inspiriert durch NetLogo Models Library Turtles Cycling
    hatch 1 [
      set color 9.9
      set heading 0
      let umfang 2 * pi * average   ;;average ist Radius der Filterblase
      set agenty agenty + average
      let one 1
      let check false
      if agenty > max-pycor + 0.499[
        set agenty agenty - (2 * average)
        set one -1
        set check true
      ]
      setxy agentx agenty
      set heading 90
      let movement (pi * average) / 180
      pen-down
      fd movement
      rt one
      while [umfang > 0][
        fd movement
        rt one
        (ifelse [xcor] of self < min-pxcor - 0.499[  ;;Überprüfung, ob die den Kreis zeichnende turtle den Rand der Welt erreicht
          pu
          set heading 0
          setxy agentx agenty  ;;falls ja, auf die Ursprungsposition zurücksetzen und in die entgegengesetzte Richtung laufen
          set heading 270
          pd
          set one -1
        ][ycor] of self < min-pycor - 0.499[
          pu
          set heading 0
          setxy agentx agenty
          set heading 270
          pd
          set one -1
        ][xcor] of self > max-pxcor + 0.499[
          pu
          set heading 0
          setxy agentx agenty
          set heading 270
          pd
          set one -1
        ][ycor] of self > max-pycor + 0.499[
          pu
          set heading 0
          setxy agentx agenty
          set heading 270
          pd
          set one 1
        ])
        set umfang umfang - movement
      ]
      die
    ]
  ]
end

to initializeCluster  ;;initiales Befüllen der Tabellen für die Clusteranalyse und den Test von Mojena
  let ende1 self
  let ende2 0
  let distanz 0
  foreach sort guys[ ;;Durchlaufen aller Agenten und Herstellen der für die Clusteranalyse nötigen Beziehung, falls noch nicht vorhanden. Dopplungen werden vermieden
    i -> if cluster-neighbor? i = false and i != ende1[
      create-cluster-with i
      ask clustering[hide-link]
      set ende2 i
      set distanz euclidDistance i
      table:put agent1 counter ende1  ;;Befüllung der Tabellen, die jeweils für die Clusteranalyse und die Clusterzuweisung verwendet werden
      table:put agent1copy counter ende1
      table:put agent2 counter ende2
      table:put agent2copy counter ende2
      table:put data counter distanz
      table:put datacopy counter distanz
      set counter counter + 1
    ]
  ]
end


to clusterAnalyse  ;;Die eigentliche Clusteranalyse, die zur Vorbereitung der Clusterzuwesiung dient
  let euklid1 0
  let euklid2 0
  let ende1 0
  let ende2 0
  let currentCluster 0  ;;gibt den Tabellenwert an, an dem die beiden zu clusternden Agenten stehen
  let a 0
  let break 0
  ;;Verbindung mit kleinster Distanz ermitteln
  if table:length datacopy > 0[
    let minValue min table:values datacopy ;;minValues entspricht nun dem kleinsten Wert in der Tabelle
    while[a <= counter][
      if table:has-key? datacopy a and table:get datacopy a = minValue[
        set currentCluster a
        set break counter + 1 ;;Hilfsvariable zum vorzeitigen Abbrechen der Schleife. So muss die datacopy-Tabelle nicht vollständig durchlaufen werden, wenn der gesuchte Wert früh in der Tabelle zu finden ist.
      ]
      ifelse counter < break[  ;;Überprüfung, ob die Schleife schon abgebrochen werden kann oder nicht
        set a break
      ][
        set a a + 1
      ]
    ]
    if table:has-key? datacopy currentCluster and clusternr >= 0[
      table:put mojenatable clusternr table:get datacopy currentCluster  ;;Hinzufügen des Fusionskoeffizienten pro Schritt in die Tabelle, die zur Berechnung des Tests von Mojena verwendet wird
      set clusternr clusternr - 1
    ]
    if table:has-key? agent1copy currentCluster and table:has-key? agent2copy currentCluster[
      set ende1 table:get agent1copy currentCluster
      set ende2 table:get agent2copy currentCluster
      table:remove agent1copy currentCluster
      table:remove agent2copy currentCluster
      table:remove datacopy currentCluster
      ;;hier auch neuberechnung der tabellen mit average linkage (siehe Backhaus et al. 2018: 465f.)
      ask clustering with [end1 = ende2 or end2 = ende2][die]
      let i 0
      while[i <= counter][   ;;separate Betrachtungen, ob sich einer der geclusterten Agenten in Tabelle 1 oder 2 befindet
                             ;;dementsprechend Änderungen in der Tabelle
        if table:has-key? agent1copy i and table:get agent1copy i = ende1[     ;;Bestimmung der Distanz zw. Agent 1 und einem anderen Agenten (temp)
          let temp table:get agent2copy i
          let var 0
          let tempspot 0
          set break 0
          ;;euklidische Distanz zw den beiden geclusterten Agenten berechnen. Die Schleife sucht den Wert von d(ende2, var)
          while[var <= counter][
            (ifelse table:has-key? agent1copy var and table:has-key? agent2copy var and table:get agent1copy var = ende2 and table:get agent2copy var = temp[
              set euklid2 table:get datacopy var
              set break counter + 1
            ]table:has-key? agent1copy var and table:has-key? agent2copy var and table:get agent1copy var = temp and table:get agent2copy var = ende2[
              set euklid2 table:get datacopy var
              set break counter + 1
            ])
            ifelse counter < break[
              table:remove agent1copy var
              table:remove agent2copy var
              table:remove datacopy var
              set var break
            ][
              set var var + 1
            ]
          ]
          set euklid1 table:get datacopy i
          set euklid1 0.5 * (euklid1 +  euklid2)  ;;Neuer Distanzwert zw. Cluster und temp nach average linkage
          table:put datacopy i euklid1
        ]
        if table:has-key? agent2copy i and table:get agent2copy i = ende1[
          let temp table:get agent1copy i
          let var 0
          let tempspot 0
          set break 0
          while[var <= counter][
            (ifelse table:has-key? agent1copy var and table:has-key? agent2copy var and table:get agent1copy var = ende2 and table:get agent2copy var = temp[
              set euklid2 table:get datacopy var
              set break counter + 1
              ]
              table:has-key? agent1copy var and table:has-key? agent2copy var and table:get agent1copy var = temp and table:get agent2copy var = ende2[
                set euklid2 table:get datacopy var
                set break counter + 1
            ])
            ifelse counter < break[
              table:remove agent1copy var
              table:remove agent2copy var
              table:remove datacopy var
              set var break
            ][
              set var var + 1
            ]
          ]
          set euklid1 table:get datacopy I
          set euklid1 0.5 * (euklid1 +  euklid2)  ;;Neuer Distanzwert zw. Cluster und temp nach average linkage
          table:put datacopy i euklid1
        ]
        set i i + 1
      ]
    ]
  ]
end


to clusterzuweisung ;;Funktion für die Zuweisung der Agenten zu ihren Cluster
  let a 0
  let currentCluster 0
  let ende1 0
  let ende2 0
  let dist1 0
  let dist2 0
  let break 0
  if elbownumber > mojena[  ;;sollte der über das Elbow-Kriterium abgelesene und eingetragene Wert höher sein als der durch den Test von Mojena berechnete Wert, wird dieser als ideale Clusterzahl verwendet
    set mojena elbownumber
  ]
  if table:length agent1 > 0 and zuweisung <= mojena[
    ;;Suchen der kleinsten Distanz zw. Agenten
    let minValue min table:values data
    while[a <= counter][
      if table:has-key? data a and table:get data a = minValue[
        set currentCluster a
        set break counter + 1
      ]
      ifelse counter < break[
        set a break
      ][
        set a a + 1
      ]
    ]
    ;;Zuweisung des Clusters, von dem man in diesem Durchgang ausgeht
    set ende1 table:get agent1 currentCluster
    set ende2 table:get agent2 currentCluster
    ask ende1[set clusternumber zuweisung]
    ask ende2[set clusternumber zuweisung]
    table:remove agent1 currentCluster
    table:remove agent2 currentCluster
    table:remove data currentCluster
    ;;Berechnen der neuen euklidischen Distanzen ausgehend vom neuen Cluster
    let i 0
    while[i <= counter][
      (ifelse table:has-key? agent1 i and table:get agent1 i = ende1[
        let temp table:get agent2 i
        set dist1 table:get data i
          ;;Berechnung der neuen euklidischen Distanz
        let var 0
        set break 0
        while[var <= counter][
          (ifelse table:has-key? agent1 var and table:has-key? agent2 var and table:get agent1 var = ende2 and table:get agent2 var = temp[
            set dist2 table:get data var
            set break counter + 1
            ]
            table:has-key? agent1 var and table:has-key? agent2 var and table:get agent1 var = temp and table:get agent2 var = ende2[
              set dist2 table:get data var
              set break counter + 1
          ])
          ifelse counter < break[
            table:remove agent1 var
            table:remove agent2 var
            table:remove data var
            set var break
          ][
            set var var + 1
          ]
        ]
        set dist1 0.5 * (dist1 +  dist2)  ;;Neuer Distanzwert zw. Cluster und temp nach average linkage
        table:put data i dist1
      ]table:has-key? agent2 i and table:get agent2 i = ende1[
        let temp table:get agent1 i
        set dist1 table:get data i
          ;;Berechnung der neuen euklidischen Distanzen
        let var 0
        let tempspot 0
        set break 0
        while[var <= counter][
          (ifelse table:has-key? agent1 var and table:has-key? agent2 var and table:get agent1 var = ende2 and table:get agent2 var = temp[
            set dist2 table:get data var
            set break counter + 1
            ]
            table:has-key? agent1 var and table:has-key? agent2 var and table:get agent1 var = temp and table:get agent2 var = ende2[
              set dist2 table:get data var
              set break counter + 1
          ])
          ifelse counter < break[
            table:remove agent1 var
            table:remove agent2 var
            table:remove data var
            set var break
          ][
            set var var + 1
          ]
        ]
        set dist1 0.5 * (dist1 +  dist2)  ;;Neuer Distanzwert zw. Cluster und temp nach average linkage
        table:put data i dist1
      ])
      set i i + 1
    ]
    ;;Schleife zum Suchen nach der kleinsten Verbindung, an der das Cluster der beiden Agenten teilnimmt. Auf diese Weise wird das anfangs gefundene Cluster vollständig gefunden.
    let s 0
    while[s <= counter][
      set a 0
      let distanz 9999
      set currentCluster 0
      ;;Suchen des Partners mit der kleinsten Distanz zum aktuellen Cluster. Das aktuelle Cluster wird durch ende1 abgebildet bzw. referenziert.
      while[a <= counter][
        if table:has-key? agent1 a and table:get agent1 a = ende1 and table:get data a < distanz[
          set distanz table:get data a
          set currentCluster a
          set ende2 table:get agent2 currentCluster
        ]
        if table:has-key? agent2 a and table:get agent2 a = ende1 and table:get data a < distanz[
          set distanz table:get data a
          set currentCluster a
          set ende2 table:get agent1 currentCluster
        ]
        set a a + 1
      ]
      if table:get data currentCluster < mittelwert and [clusternumber] of ende2 = 0[  ;;Überprüfung, ob der dem Cluster nächste Agent nah genug ist, um dem Cluster zugehörig zu sein. Clusternumber von ende2 ist null, da jedes Cluster vollständig gebildet wird, ehe das nächste Cluster gebildet wird.
        ask ende2 [set clusternumber zuweisung]
        table:remove agent1 currentCluster
        table:remove agent2 currentCluster
        table:remove data currentCluster
        ;;Neue Distanzmaße zu allen anderen Agenten berechnen über vorhandene Distanzmaße
        set i 0
        while[i <= counter][
          (ifelse table:has-key? agent1 i and table:get agent1 i = ende1[
            let temp table:get agent2 i
            set dist1 table:get data i
            ;;Berechnung der neuen euklidischen Distanz
            set a 0
            set break 0
            while[a <= counter][
              (ifelse table:has-key? agent1 a and table:has-key? agent2 a and table:get agent1 a = ende2 and table:get agent2 a = temp[
                set dist2 table:get data a
                set break counter + 1
                ]
                table:has-key? agent1 a and table:has-key? agent2 a and table:get agent1 a = temp and table:get agent2 a = ende2[
                  set dist2 table:get data a
                  set break counter + 1
              ])
              ifelse counter < break[
                table:remove agent1 a
                table:remove agent2 a
                table:remove data a
                set a break
              ][
                set a a + 1
              ]
            ]
            set distanz 0.5 * (dist1 +  dist2)  ;;Neuer Distanzwert zw. Cluster und temp nach average linkage
            table:put data i distanz
          ]table:has-key? agent2 i and table:get agent2 i = ende1[
            let temp table:get agent1 i
            set dist1 table:get data i
            ;;Berechnung der neuen euklidischen Distanzen
            set a 0
            set break 0
            while[a <= counter][
              (ifelse table:has-key? agent1 a and table:has-key? agent2 a and table:get agent1 a = ende2 and table:get agent2 a = temp[
                set dist2 table:get data a
                set break counter + 1
                ]
                table:has-key? agent1 a and table:has-key? agent2 a and table:get agent1 a = temp and table:get agent2 a = ende2[
                  set dist2 table:get data a
                  set break counter + 1
              ])
              ifelse counter < break[
                table:remove agent1 a
                table:remove agent2 a
                table:remove data a
                set a break
              ][
                set a a + 1
              ]
            ]
            set distanz 0.5 * (dist1 +  dist2)  ;;Neuer Distanzwert zw. Cluster und temp nach average linkage
            table:put data i distanz
          ])
          set i i + 1
        ]
      ]
      set s s + 1
    ]
    ask guys with [clusternumber = zuweisung][set color 10 * zuweisung + 5]
    set zuweisung zuweisung + 1
  ]
end

to testOfMojena
   ;;Berechnung des Tests von Mojena
  let a 0
  let idealClusterCount 0
  while[a < counter][  ;;volständiges Durchlaufen der Tabelle für den Test von Mojena, um den Fusionskoeffizienten von jedem Schritt zu erhalten und so den standardisierten Fusionskoeffizienten berechnen zu können
  if table:has-key? mojenatable a[
    let temp table:get mojenatable a
    set temp (temp - mittelwert) / abweichung
    if temp > 1.8 and temp < 2.7[  ;;der Wert, der dieses Kriterium erfüllt, soll als ideale Clusterzahl angesehen werden (vgl. Backhaus et al. 2018: 478)
    set idealClusterCount a
    ]
   ]
  set a a + 1
  ]
  set mojena idealClusterCount
  table:clear mojenatable
  output-print word "Ideale Clusterzahl nach dem Test von Mojena: " mojena
end

to-report distanzmittelwert  ;;Berechnung des mittleren Fusionskoeffizienten für den Test von Mojena und die Clusterzuweisung
  let i 0
  let mittel 0
  let check table:length mojenatable
  while[i < check][
    if table:has-key? mojenatable i[
      set mittel mittel + table:get mojenatable i
    ]
    set i i + 1
  ]
  set mittel mittel / i
  report mittel
end

to getMathValues ;;Getter-Methode, um die berechneten Werte den globalen Variablen zuzuordnen
  set mittelwert distanzmittelwert
  set abweichung standardabweichung
  output-print word "Mittelwert für Mojena: " mittelwert
  output-print word "Varianz für Mojena: " abweichung
end

to-report standardabweichung   ;;Berechnung der Standardabweichung der Koeffizienten für den Test von Mojena
  let avg distanzmittelwert
  let i 0
  let varianz 0
  let check table:length mojenatable
  while[i < check][
    if table:has-key? mojenatable i[
      set varianz varianz + (table:get mojenatable i - avg) ^ 2
    ]
    set i i + 1
  ]
  set check check - 2
  set varianz varianz / check
  set varianz sqrt varianz
  report varianz
end

to-report euclidDistance [anotherguy] ;;Berechnung der euklidischen Distanz zwischen dem aufrufenden Agenten und anotherguy
  let ownx [xcor] of self
  let owny [ycor] of self
  let otherx [xcor] of anotherguy
  let othery [ycor] of anotherguy
  let varx ownx - otherx
  let vary owny - othery
  set varx varx ^ 2
  set vary vary ^ 2
  report (varx + vary)
end

to-report integration-probability [dist] ;;Nach Geschke et al., Anpassung auf dieses Modell durch Abbildung der 65x65 Welt in einen Attitude Space, dessen Koordinaten jeweils von -1 bis +1 reichen
  let D [latitude] of one-of guys / (max-pxcor + 0.5)
  report D ^ 20 / ((dist / (max-pxcor + 0.5)) ^ 20 + D ^ 20)
end
@#$#@#$#@
GRAPHICS-WINDOW
199
11
1052
865
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-32
32
-32
32
0
0
1
ticks
30.0

BUTTON
9
10
91
52
go
go
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
105
10
193
53
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

SLIDER
10
206
195
239
agentnumber
agentnumber
1
500
250.0
1
1
NIL
HORIZONTAL

BUTTON
10
752
195
785
Freunde anzeigen
ask friendships[show-link]\nask sourcefriends[show-link]\n
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
10
791
195
824
Freunde verbergen
ask friendships[hide-link]\nask sourcefriends[hide-link]
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
10
831
195
864
Informationen verbergen
ask information[hide-turtle]
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
10
871
194
904
Informationen anzeigen
ask information[show-turtle]
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
10
911
195
944
Link zw. Person&Info verbergen
ask knowledge[hide-link]\nask sourceknowledge[hide-link]
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
10
712
194
745
Filterblasen anzeigen
ask guys [showFilterbubble]
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
10
674
193
707
Clusterzuweisung durchführen
ask guys[clusterzuweisung]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
12
400
196
433
algorithmicRecommendation
algorithmicRecommendation
1
1
-1000

SWITCH
12
439
196
472
collaborative
collaborative
1
1
-1000

SWITCH
11
478
196
511
contentbased
contentbased
1
1
-1000

SWITCH
12
517
196
550
algorithmicFriends
algorithmicFriends
1
1
-1000

SWITCH
12
362
195
395
sharing
sharing
1
1
-1000

SWITCH
11
555
194
588
sourcecredibility
sourcecredibility
1
1
-1000

SWITCH
11
595
194
628
latitudeFunction
latitudeFunction
1
1
-1000

SLIDER
10
167
194
200
memory
memory
0
30
15.0
1
1
NIL
HORIZONTAL

BUTTON
10
952
196
985
Link zw. Person&Info anzeigen
ask knowledge[show-link]\nask sourceknowledge[show-link]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
129
193
162
potentialFriends
potentialFriends
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
10
245
195
278
acceptanceLatitude
acceptanceLatitude
0
10
5.0
0.1
1
NIL
HORIZONTAL

SLIDER
10
285
195
318
chanceToShare
chanceToShare
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
10
90
193
123
initialInformation
initialInformation
0
2
1.0
0.1
1
NIL
HORIZONTAL

SWITCH
11
324
195
357
informationRemoval
informationRemoval
0
1
-1000

PLOT
1057
86
2103
896
Ellbogen
NIL
NIL
0.0
10.0
0.0
1000.0
false
false
"if ticks = 8760[\nset-plot-x-range 0 table:length mojenatable\n]\n" ""
PENS
"default" 1.0 0 -16777216 true "" "\nif table:has-key? mojenatable elbowlength[\n plot (table:get mojenatable elbowlength / 2)\n]\n \n"

OUTPUT
1056
11
1865
83
11

INPUTBOX
1869
11
2101
83
elbownumber
0.0
1
0
Number

TEXTBOX
53
59
203
86
Parameter
22
0.0
1

TEXTBOX
47
635
197
662
Funktionen
22
0.0
1

@#$#@#$#@
## WAS IST DIESES MODELL?

Es liegt eine agentenbasierte Simulationsumgebung zur Betrachtung und Analyse von Filterblasen und Echokammern vor. Diese wurde im Rahmen der zur Erlangung des akademischen Grades Bachelor of Science vorgelegten Thesis "Konzipierung, Umsetzung und Analyse einer agenten-basierten Simulationsumgebung zur Untersuchung von Filterblasen und Echokammern" zunächst konzipiert und anschließend in Form dieses Programms umgesetzt.


## WIE ES FUNKTIONIERT

Die Welt bildet einen zweidimensionalen Raum der Einstellungen ab. Dabei stellt die Position eines Agenten seine Ansichten dar. Über die latitude of acceptance (nach Sherif und Hovland) wird angegeben, wie weit eine Information von einer Person entfernt sein darf, um als relevant zu gelten und integriert zu werden. Diese kann dabei entweder als absoluter Grenzwert festgelegt werden oder es kann eine Funktion nach Geschke et al. verwendet werden. Die Position eines Agenten nach dem Integrieren von Informationen ergibt sich aus den durchschnittlichen Koordinatenwerten seiner integrierten Informationen. Das Modell verfügt über verschiedene Parameter, die Einfluss auf die Entwicklung von Echokammern und Filterblasen nehmen können. Filterblasen werden als Kreise mit dem Radius der durchschnittlichen Entfernung aller integrierten Informationen dargestellt. Echokammern werden anhand einer Clusteranalyse gefunden.

**Es kann sein, dass NetLogo mehr RAM zugewiesen werden muss, um einige Modelldurchläufe mit einer hohen Anzahl an Agenten durchführen zu können. Eine Beschreibung findet sich [hier](http://ccl.northwestern.edu/netlogo/docs/faq.html) unter der Frage "How big can my model be? How many turtles, patches, procedures, buttons and so on can my model contain?".**

## WIE MAN ES BENUTZEN KANN

Eine kurze Beschreibung der jeweiligen Parametrer und Funktionen:

**--------------------------------Parameter------------------------------------------------**

_initialInformation_: Faktor, der angibt, wie viele Informationen bei Erstellung der Welt initalisiert werden, prozentual abhängig von der Anzahl an Personen

_potentialFriends_: Maximale Anzahl an Freunden, die eine Person haben kann.

_memory_: Gedöchtnis einer Person, begrenzt max. integrierbare Informationen

_agentnumber_: Gibt Anzahl der Personen für den jeweiligen Durchlauf an

_acceptanceLatitude_: Ein Wert, der die latitude of acceptance einer jeden Person bestimmt

_chanceToShare_: Gibt an, mit welcher Wahrscheinlichkeit Inhalte, die integriert wurden, direkt mit einem Freund geteilt werden. Kann auch auf bereits geteilte Inhalte angewendet werden

_informationRemoval_: Alle 56 ticks werden alle nicht von Personen integrierten Informationen gelöscht

_sharing_: Erlaubt das Teilen von Informationen unter befreundeten Agenten

_algorithmicRecommendation_: Aktiviert algorithmische Empfehlungsdienste

_collaborative_: Nur in Kombination  mit algorithmicRecommendation. Aktiviert kollaborative Empfehlungen

_contentbased_: Nur in Kombination mit algorithmicRecommendation. Aktiviert inhaltsbasierte Empfehlungen

_algortihmicFriends_: Aktiviert das algortihmische Empfehlen von Freunden

_sourcecredibility_: Baut den Faktor source credibility bzw. Vertrauensverhältnisse in das Modell ein

_latitudeFunction_: Die latitude of acceptance wird nicht als absoluter Grenzwert, sondern als Funktion zur Berechnung der Integrationswahrscheinlichkeit nach Geschke et al. (2019) ab

**--------------------------------Funktionen-----------------------------------------------**

_Clusterzuweisung ausführen_: Die Agenten werden ihren durch die Clusteranalyse berechneten Clustern zugeordnet und entsprechend gefärbt

_Filterblasen anzeigen_: Es werden die Filterblasen aller Agenten angezeigt

_Freunde anzeigen_: Alle Freundschaftsbeziehungen unter Agenten werden in der Welt sichtbar

_Freunde verbergen_: Alle Freundschaftsbeziehungen unter Agenten werden in der Welt unsichtbar

_Informationen verbergen_: Alle Informationen werden in der Welt sichtbar

_Informationen anzeigen_: Alle Informationen werden in der Welt unsichtbar

_Link zw. Person&Info verbergen_: Die Links zwischen Personen und Informationen werden unsichtbar

_Link zw. Person&Info anzeigen_: Die Links zwischen Personen und Informationen werden sichtbar


## WAS MAN AUSPROBIEREN KANN

Von Interesse für ein*e Anwender\*in dieses Modells sind vor allem die vorgestellten Parameter. Diese lassen sich frei kombinieren, wodurch eine große Zahl an verschiedenen Simulationen möglich ist. Dabei ist insbesondere der Akzeptanzschwellenwert interessant, weil er die Ergebnisse sehr stark beeinflusst. Das liegt daran, dass über diesen Parameter angegeben werden kann, wie weit Informationen entfernt sein dürfen, um noch integriert zu werden.

## DAS MODELL ERWEITERN

Eine sehr interessante Erweiterung wäre das Einbauen und Betrachten des Faktors Fake News.


## VERWANDTE MODELLE

Daniel Geschke, Jan Lorentz & Peter Holtz 2019: The triple-filter bubble: Using agent-based modelling to test a meta-theoretical framework for the emergence of filter bubbles and echo chambers

## CREDITS AND REFERENCES
Programmiert von Marc Ludwig.

Für die Clusteranalyse: Backhaus, Klaus, Bernd Erichson, Wulff Plinke &Rolf Weiber (2018): Multivariate Analyseme-thoden: Eine anwendungsorientierte Einführung, 15. Auflage, Springer-Verlag Berlin Heidelberg 2018, 
doi: https://doi.org/10.1007/978-3-662-56655-8

Für die Darstellung der latitude of acceptance:
Geschke, Daniel, Jan Lorenz & Peter Holtz, 2019. The triple-filter bubble: Using agent-based modelling to test a meta-theoretical framework for the emergence of filter bubbles and echo chambers. British Journal of Social Psychology, Vol.58 Issue 1, pp. 129-149, 
doi: https://doi.org/10.1111/bjso.12286

Für die Darstellung der Filterblasen:
Wilensky, 1999: NetLogo Turtles Circling model: https://ccl.northwestern.edu/netlogo/models/TurtlesCircling
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
