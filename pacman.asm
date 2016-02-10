Grosse merde!!!

;;===========================================================================;;
;;================================= Pac-Man =================================;;
;;======================== Produit par Steve Duquet =========================;;
;;====================== C�gep de Drummondville - 2015 ======================;;
;;===========================================================================;;
;;
;; $0000-0800 - M�moire vive interne, puce de 2KB dans la NES
;; $2000-2007 - Ports d'acc�s du PPU
;; $4000-4017 - Ports d'acc�s de l'APU
;; $6000-7FFF - WRAM optionnelle dans la ROM
;; $8000-FFFF - ROM du programme
;;
;; Contr�le du PPU ($2000)
;; 76543210
;; ||||||||
;; ||||||++- Adresse de base de la table de noms
;; ||||||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
;; ||||||
;; |||||+--- Incr�ment de l'adresse en VRAM � chaque �criture du CPU
;; |||||     (0: incr�ment par 1; 1: incr�ment par 32 (ou -1))
;; |||||
;; ||||+---- Adresse pour les motifs de sprites (0: $0000; 1: $1000)
;; ||||
;; |||+----- Adresse pour les motifs de tuiles (0: $0000; 1: $1000)
;; |||
;; ||+------ Taille des sprites (0: 8x8; 1: 8x16)
;; ||
;; |+------- Inutilis�
;; |
;; +-------- G�n�rer un NMI � chaque VBlank (0: off; 1: on)
;;
;; Masque du PPU ($2001)
;; 76543210
;; ||||||||
;; |||||||+- Nuances de gris (0: couleur normale; 1: couleurs d�satur�es)
;; |||||||   Notez que l'intensit� des couleurs agit apr�s cette valeur!
;; |||||||
;; ||||||+-- D�sactiver le clipping des tuiles dans les 8 pixels de gauche
;; ||||||
;; |||||+--- D�sactiver le clipping des sprites dans les 8 pixels de gauche
;; |||||
;; ||||+---- Activer l'affichage des tuiles
;; ||||
;; |||+----- Activer l'affichage des sprites
;; |||
;; ||+------ Augmenter l'intensit� des rouges
;; ||
;; |+------- Augmenter l'intensit� des verts
;; |
;; +-------- Augmenter l'intensit� des bleus
;;
;;===========================================================================;;
;;=============================== D�clarations ==============================;;
;;===========================================================================;;

	.inesprg 1		; Banque de 1x 16KB de code PRG
	.ineschr 1		; Banque de 1x 8KB de donn�es CHR
	.inesmap 0		; Aucune �change de banques
	.inesmir 1		; Mirroir du background

;;===========================================================================;;
;;============================== Initialisation =============================;;
;;===========================================================================;;

	.bank 0			; Banque 0
	.org $8000		; L'�criture commence � l'adresse $8000
	.code			; D�but du programme

;;---------------------------------------------------------------------------;;
;;------ Reset: Initialise le PPU et le APU au d�marrage du programme -------;;
;;---------------------------------------------------------------------------;;
Reset:
	SEI				; D�sactive l'IRQ
	CLD				; D�sactive le mode d�cimal
	LDX #$FF		; Charge $FF (255) dans X
	TXS				; Initialise la pile � 255
	INX				; Incr�mente X
	STX $2000		; Place X dans $2000 et d�sactive le NMI
	STX $2001		; Place X dans $2001 et d�sactive l'affichage
	STX $4010		; Place X dans $4010 et d�sactive le DMC
	
	;;;;  Initialization du systeme audio  ;;;;
	LDA #%00001111	; Activer les canaux carre 1, carre 2, triangle et Bruit
	STA $4015
	LDA #%00000000	; Desactiver tous les effets du canal carre 1
	STA $4001
	LDA #%00000000	; Desactiver tous les effets du canal carre 2
	STA $4005
	LDA #%00000000	; Mode 4 cycles et Interruption au 60 Hz (voir bit 6 de $2015 plus bas)
	STA $4017

	LDA #0
	STA frameCounter
	STA tempoCounter
	
	JSR VBlank

;;---------------------------------------------------------------------------;;
;;-------------------- Clear: Remet la m�moire RAM � z�ro -------------------;;
;;---------------------------------------------------------------------------;;
Clear:
	LDA #$00		; Charge $00 (0) dans A
	STA $0000, x	; Place A dans $00XX
	STA $0100, x	; Place A dans $01XX
	STA $0300, x	; Place A dans $03XX
	STA $0400, x	; Place A dans $04XX
	STA $0500, x	; Place A dans $05XX
	STA $0600, x	; Place A dans $06XX
	STA $0700, x	; Place A dans $07XX
	LDA #$FF		; Charge $FF (255) dans A
	STA $0200, x	; Place A dans $02XX
	INX				; Incr�mente X
	BNE Clear		; Recommence Clear si X n'est pas 0
	JSR VBlank		; Attend un chargement d'image complet avant de continuer
	JSR PPUInit		; Initialise le PPU avant de charger le reste
	
;;---------------------------------------------------------------------------;;
;;--------- LoadPalettes: Charge les palettes de couleur en m�moire ---------;;
;;---------------------------------------------------------------------------;;
LoadPalettes:
	LDA $2002		; Lis l'�tat du PPU pour r�initialiser son latch
	LDA #$3F		; Charge l'octet le plus significatif ($3F) dans A
	STA $2006		; Place A dans $2006
	LDA #$00		; Charge l'octet le moins significatif ($00) dans A
	STA $2006		; Place A dans $2006
	LDY #$00		; Charge $00 (0) dans Y

;;---------------------------------------------------------------------------;;
;;----------- LoadPalettesLoop: Boucle de chargement des palettes -----------;;
;;---------------------------------------------------------------------------;;
LoadPalettesLoop:
	LDA Palette, y	; Charge le premier octet de la Palette (+ Y) dans A
	STA $2007		; Place A dans $2007
	INY				; Incr�mente Y
	CPY #$20		; Compare Y avec $20 (32)
	BNE LoadPalettesLoop	; Recommence LoadPalettesLoop si Y < 32
  
;;---------------------------------------------------------------------------;;
;;--------------- LoadSprites: Charge les sprites en m�moire ----------------;;
;;---------------------------------------------------------------------------;;
LoadSprites:
	LDY #$00		; Charge $00 (0) dans Y

;;---------------------------------------------------------------------------;;
;;------------ LoadSpritesLoop: Boucle de chargement des sprites ------------;;
;;---------------------------------------------------------------------------;;
LoadSpritesLoop:
	LDA Sprites, y	; Charge le premier octet des Sprites (+ Y) dans A
	STA $0200, y	; Place A dans $02YY
	INY				; Incr�mente Y
	CPY #$50		; Compare Y avec $50 (80)
	BNE LoadSpritesLoop		; Recommence LoadSpritesLoop si Y < 80
	JSR PPUInit		; Appelle l'initialisation du PPU

;;===========================================================================;;
;;=================================== Code ==================================;;
;;===========================================================================;;

RemiseZero:		; Initialisation des variables du jeu
	
	; Pac-Man
	LDA #4			; D�termine si le d�placement est sur l'axe des x(4)		
	STA xyPacMan 	; ou des y(1) pour un Sprite.	
	LDA #1			; La distance du d�placement d'un Sprite
	STA dPacMan
	
	LDA #1		; Fant�me 1
	STA xyFantome1
	LDA #-1
	STA dFantome1
	
	LDA #1		; Fant�me 2
	STA xyFantome2
	LDA #1
	STA dFantome2
	
	LDA #4		; Fant�me 3
	STA xyFantome3
	LDA #1
	STA dFantome3

	LDA #4		; Fant�me 4
	STA xyFantome4
	LDA #-1
	STA dFantome4
	
	LDA #1					; Num�ro du Fant�me contr�l�
	STA fantomeControler
	
	LDA #1					; Indice pour la bouche du Pac-Man
	STA bouchePacMan
	
	; Num�ros et Attributs des Sprites du Pac-Man avec la bouche ouverte
	LDA #0					; Num�ro de la tuile dans la table des motifs
	STA sauvegardePacMan1
	LDA #%00000000			; Attributs du Sprite
	STA sauvegardePacMan2
	LDA #1
	STA sauvegardePacMan3
	LDA #%00000000
	STA sauvegardePacMan4
	LDA #0
	STA sauvegardePacMan5
	LDA #%10000000
	STA sauvegardePacMan6
	LDA #1
	STA sauvegardePacMan7
	LDA #%10000000
	STA sauvegardePacMan8

;;---------------------------------------------------------------------------;;
;;------------------- Forever: Boucle infinie du programme ------------------;;
;;---------------------------------------------------------------------------;;

Forever:
	
	;;;;  Musique du jeu  ;;;;
	LDA $4015		
	AND #%01000000	; Le bit 6 de $2015 ce met � 1 � une fr�quence de 60 Hz (Un Frame)
	BEQ Forever
	INC frameCounter
	LDA frameCounter
	CMP #10		; 10 Frames = 1 Tempo � 400 Noirs / Minutes (6 noirs / secondes)
	BNE Forever
	LDA #0
	STA frameCounter
	INC tempoCounter
	JSR Tempo
	JMP Forever		; Recommence Forever jusqu'� la prochaine interruption

Tempo: ; � chaque coups de tempo, joue redirige vers les routines des Note_* � jouer
	LDA #%10000000	; Silence le canal Triangle
	STA $4008
	LDA #%00000000	; Silence le canal de bruit
	STA $400C
	LDA tempoCounter
	CMP #1
	BEQ Note1
	CMP #2
	BEQ Note3
	CMP #3
	BEQ Note2
	CMP #4
	BEQ Cymbale
	CMP #5
	BEQ Note2
	CMP #23
	BEQ Note2
	CMP #24
	BEQ Note3
	CMP #25
	BEQ Note1
	CMP #26
	BEQ Cymbale
	JMP Tempo2

Cymbale:
	LDA #0			; Desactiver la r�p�tition et la gestion de la dur�e
	STA $400F
	LDA #%00000101	; Mode et type de bruit
	STA $400E
	LDA #%00100111	; Volume
	STA $400C

	RTS

Note1:
	LDA #%11000111
	STA $4000
	LDA #$FD		; A � l'octave 4 avec le canal Carr� 1
	STA $4002
	LDA #$08
	STA $4003

	LDA #%11000111
	STA $4004
	LDA #$FD		; A � l'octave 4 avec le canal Carr� 2
	STA $4006
	LDA #$08
	STA $4007

	RTS
	
Note2:
	LDA #%11000111
	STA $4000
	LDA #$E2		; B � l'octave 4 avec le canal Carr� 1
	STA $4002
	LDA #$08
	STA $4003

	LDA #%11000111
	STA $4004
	LDA #$E2		; B � l'octave 4 avec le canal Carr� 2
	STA $4006
	LDA #$08
	STA $4007

	RTS

Note3:
	LDA #%11000111
	STA $4000
	LDA #$D2		; C � l'octave 4 avec le canal Carr� 1
	STA $4002
	LDA #$08
	STA $4003

	LDA #%11000111
	STA $4004
	LDA #$D2		; C � l'octave 4 avec le canal Carr� 2
	STA $4006
	LDA #$08
	STA $4007

	RTS
	
Tempo2:
	CMP #6
	BEQ Note4
	CMP #7
	BEQ Note5
	CMP #8
	BEQ Note6
	CMP #9
	BEQ Cymbale2
	CMP #10
	BEQ Note4
	CMP #19
	BEQ Note6
	CMP #20
	BEQ Note4
	CMP #21
	BEQ Note5
	CMP #22
	BEQ Cymbale2
	JMP Tempo3

Cymbale2:
	LDA #0			; Desactiver la r�p�tition et la gestion de la dur�e
	STA $400F
	LDA #%00000111	; Mode et type de bruit
	STA $400E
	LDA #%00100111	; Volume
	STA $400C

	RTS

Note4:
	LDA #%11000111
	STA $4000
	LDA #$BD		; D � l'octave 4 avec le canal Carr� 1
	STA $4002
	LDA #$08
	STA $4003

	LDA #%11000111
	STA $4004
	LDA #$BD		; D � l'octave 4 avec le canal Carr� 2
	STA $4006
	LDA #$08
	STA $4007

	RTS
	
Note5:
	LDA #%11000111
	STA $4000
	LDA #$A9		; E � l'octave 4 avec le canal Carr� 1
	STA $4002
	LDA #$08
	STA $4003

	LDA #%11000111
	STA $4004
	LDA #$A9		; E � l'octave 4 avec le canal Carr� 2
	STA $4006
	LDA #$08
	STA $4007

	RTS
	
Note6:
	LDA #%11000111
	STA $4000
	LDA #$9F		; F � l'octave 4 avec le canal Carr� 1
	STA $4002
	LDA #$08
	STA $4003

	LDA #%11000111
	STA $4004
	LDA #$9F		; F � l'octave 4 avec le canal Carr� 2
	STA $4006
	LDA #$08
	STA $4007

	RTS

Tempo3:
	CMP #11
	BEQ Note7
	CMP #12
	BEQ Note9
	CMP #13
	BEQ Note8
	CMP #14
	BEQ Cymbale3
	CMP #15
	BEQ Note8
	CMP #16
	BEQ Note9
	CMP #17
	BEQ Note7
	CMP #18
	BEQ Cymbale3
	CMP #27
	BEQ MusiqueZero
	
	RTS

Cymbale3:
	LDA #0			; Desactiver la r�p�tition et la gestion de la dur�e
	STA $400F
	LDA #%00000001	; Mode et type de bruit
	STA $400E
	LDA #%00100111	; Volume
	STA $400C

	RTS

Note7:
	LDA #$9F		; F � l'octave 4 avec le canal Triangle
	STA $400A
	LDA #$08
	STA $400B
	LDA #%11000000
	STA $4008
	
	RTS

Note8:
	LDA #$A9		; E � l'octave 4 avec le canal Triangle
	STA $400A
	LDA #$08
	STA $400B
	LDA #%11000000
	STA $4008
	
	RTS

Note9:
	LDA #$BD		; D � l'octave 4 avec le canal Triangle
	STA $400A
	LDA #$08
	STA $400B
	LDA #%11000000
	STA $4008
	
	RTS

MusiqueZero:
	LDA #0
	STA frameCounter
	STA tempoCounter
	
	RTS
	
;;---------------------------------------------------------------------------;;
;;------------ NMI: Code d'affichage � chaque image du programme ------------;;
;;---------------------------------------------------------------------------;;
NMI:

LireManette1:
	;Lecture des touches du contr�leur 1
	LDX #$00
	LDY #$00
	LDA #$01	; �crire $01 et $00 dans $4016
	STA $4016
	LDA #$00
	STA $4016
	;Lecture des touches du contr�leur 1
	LDA $4016, y	; A
	LDA $4016, y	; B
	LDA $4016, y	; Select
	LDA $4016, y	; Start
	
LireToucheHaut1:
	LDA $4016, y	; Haut
	AND #%00000001	; Le bouton est appuy� si le AND ne retourne pas 0
	BEQ LireToucheBas1
	LDX #1	; Change la direction du Pac-Man
	STX xyPacMan
	LDX #-1	; Change le d�placement
	STX dPacMan
	; Change et sauvegarde les Sprites
	LDX #4					; Num�ro de la tuile dans la table des motifs
	STX $0201
	STX sauvegardePacMan1
	LDX #%00000000			; Attributs du Sprite
	STX $0202
	STX sauvegardePacMan2
	LDX #4
	STX $0205
	STX sauvegardePacMan3
	LDX #%01000000
	STX $0206
	STX sauvegardePacMan4
	LDX #0
	STX $0209
	STX sauvegardePacMan5
	LDX #%10000000
	STX $020A
	STX sauvegardePacMan6
	LDX #0
	STX $020D
	STX sauvegardePacMan7
	LDX #%11000000
	STX $020E
	STX sauvegardePacMan8
	JMP FinManette1
	
LireToucheBas1:
	LDA $4016, y	; Bas
	AND #%00000001
	BEQ LireToucheGauche1
	LDX #1	; Change la direction du Pac-Man
	STX xyPacMan
	LDX #1	; Change le d�placement
	STX dPacMan
	; Change et sauvegarde les Sprites
	LDX #0					; Num�ro de la tuile dans la table des motifs
	STX $0201
	STX sauvegardePacMan1
	LDX #%00000000			; Attributs du Sprite
	STX $0202
	STX sauvegardePacMan2
	LDX #0
	STX $0205
	STX sauvegardePacMan3
	LDX #%01000000
	STX $0206
	STX sauvegardePacMan4
	LDX #4
	STX $0209
	STX sauvegardePacMan5
	LDX #%10000000
	STX $020A
	STX sauvegardePacMan6
	LDX #4
	STX $020D
	STX sauvegardePacMan7
	LDX #%11000000
	STX $020E
	STX sauvegardePacMan8
	JMP FinManette1
	
LireToucheGauche1:
	LDA $4016, y	; Gauche
	AND #%00000001
	BEQ LireToucheDroit1
	LDX #4	; Change la direction du Pac-Man
	STX xyPacMan
	LDX #-1	; Change le d�placement
	STX dPacMan
	; Change et sauvegarde les Sprites
	LDX #1					; Num�ro de la tuile dans la table des motifs
	STX $0201
	STX sauvegardePacMan1
	LDX #%01000000			; Attributs du Sprite
	STX $0202
	STX sauvegardePacMan2
	LDX #0
	STX $0205
	STX sauvegardePacMan3
	LDX #%01000000
	STX $0206
	STX sauvegardePacMan4
	LDX #1
	STX $0209
	STX sauvegardePacMan5
	LDX #%11000000
	STX $020A
	STX sauvegardePacMan6
	LDX #0
	STX $020D
	STX sauvegardePacMan7
	LDX #%11000000
	STX $020E
	STX sauvegardePacMan8
	JMP FinManette1
	
LireToucheDroit1:
	LDA $4016, y	; Droit
	AND #%00000001
	BEQ FinManette1
	LDX #4	; Change la direction du Pac-Man
	STX xyPacMan
	LDX #1	; Change le d�placement
	STX dPacMan
	; Change et sauvegarde les Sprites
	LDX #0					; Num�ro de la tuile dans la table des motifs
	STX $0201
	STX sauvegardePacMan1
	LDX #%00000000			; Attributs du Sprite
	STX $0202
	STX sauvegardePacMan2
	LDX #1
	STX $0205
	STX sauvegardePacMan3
	LDX #%00000000
	STX $0206
	STX sauvegardePacMan4
	LDX #0
	STX $0209
	STX sauvegardePacMan5
	LDX #%10000000
	STX $020A
	STX sauvegardePacMan6
	LDX #1
	STX $020D
	STX sauvegardePacMan7
	LDX #%10000000
	STX $020E
	STX sauvegardePacMan8
FinManette1:

LireManette2:
	;Lecture des touches du contr�leur 2
LireToucheA2:
	LDA $4017, y	; A
	AND #%00000001
	BEQ LireToucheB2
	LDA #1
	STA fantomeControler	; Change le Fant�me contr�l�
	JMP FinManette2
LireToucheB2:
	LDA $4017, y	; B
	AND #%00000001
	BEQ LireSelect2
	LDA #2
	STA fantomeControler	; Change le Fant�me contr�l�
	JMP FinManette2
LireSelect2:
	LDA $4017, y	; Select
	AND #%00000001
	BEQ LireStart2
	LDA #3
	STA fantomeControler	; Change le Fant�me contr�l�
	JMP FinManette2
LireStart2:
	LDA $4017, y	; Start
	AND #%00000001
	BEQ LireHaut2
	LDA #4
	STA fantomeControler	; Change le Fant�me contr�l�
	JMP FinManette2
	
LireHaut2:
	LDA $4017, y	; Haut
	AND #%00000001	; Le bouton est appuy� si le AND ne retourne pas 0
	BEQ LireBas2
VoirFantome1Haut:
	LDA fantomeControler	; V�rification du Fant�me contr�ler
	CMP #1
	BNE VoirFantome2Haut
	LDX #1					; Change les valeurs de d�placement du bon Fant�me
	STX xyFantome1
	LDX #-1
	STX dFantome1
	JMP FinManette2
VoirFantome2Haut:
	LDA fantomeControler
	CMP #2
	BNE VoirFantome3Haut
	LDX #1
	STX xyFantome2
	LDX #-1
	STX dFantome2
	JMP FinManette2
VoirFantome3Haut:
	LDA fantomeControler
	CMP #3
	BNE VoirFantome4Haut
	LDX #1
	STX xyFantome3
	LDX #-1
	STX dFantome3
	JMP FinManette2
VoirFantome4Haut:
	LDA fantomeControler
	CMP #4
	BNE LireBas2
	LDX #1
	STX xyFantome4
	LDX #-1
	STX dFantome4
	JMP FinManette2
	
LireBas2:
	LDA $4017, y	; Bas
	AND #%00000001
	BEQ LireGauche2
VoirFantome1Bas:
	LDA fantomeControler	; V�rification du Fant�me contr�ler
	CMP #1
	BNE VoirFantome2Bas
	LDX #1					
	STX xyFantome1
	LDX #1
	STX dFantome1
	JMP FinManette2
VoirFantome2Bas:
	LDA fantomeControler
	CMP #2
	BNE VoirFantome3Bas
	LDX #1
	STX xyFantome2
	LDX #1
	STX dFantome2
	JMP FinManette2
VoirFantome3Bas:
	LDA fantomeControler
	CMP #3
	BNE VoirFantome4Bas
	LDX #1
	STX xyFantome3
	LDX #1
	STX dFantome3
	JMP FinManette2
VoirFantome4Bas:
	LDA fantomeControler
	CMP #4
	BNE LireGauche2
	LDX #1
	STX xyFantome4
	LDX #1
	STX dFantome4
	JMP FinManette2
	
LireGauche2:
	LDA $4017, y	; Gauche
	AND #%00000001
	BEQ LireDroit2
VoirFantome1Gauche:
	LDA fantomeControler	; V�rification du Fant�me contr�ler
	CMP #1
	BNE VoirFantome2Gauche
	LDX #4
	STX xyFantome1
	LDX #-1
	STX dFantome1
	JMP FinManette2
VoirFantome2Gauche:
	LDA fantomeControler
	CMP #2
	BNE VoirFantome3Gauche
	LDX #4
	STX xyFantome2
	LDX #-1
	STX dFantome2
	JMP FinManette2
VoirFantome3Gauche:
	LDA fantomeControler
	CMP #3
	BNE VoirFantome4Gauche
	LDX #4
	STX xyFantome3
	LDX #-1
	STX dFantome3
	JMP FinManette2
VoirFantome4Gauche:
	LDA fantomeControler
	CMP #4
	BNE LireDroit2
	LDX #4
	STX xyFantome4
	LDX #-1
	STX dFantome4
	JMP FinManette2
	
LireDroit2:
	LDA $4017, y	; Droit
	AND #%00000001
	BEQ FinManette2
VoirFantome1Droit:
	LDA fantomeControler	; V�rification du Fant�me contr�ler
	CMP #1
	BNE VoirFantome2Droit
	LDX #4
	STX xyFantome1
	LDX #1
	STX dFantome1
	JMP FinManette2
VoirFantome2Droit:
	LDA fantomeControler
	CMP #2
	BNE VoirFantome3Droit
	LDX #4
	STX xyFantome2
	LDX #1
	STX dFantome2
	JMP FinManette2
VoirFantome3Droit:
	LDA fantomeControler
	CMP #3
	BNE VoirFantome4Droit
	LDX #4
	STX xyFantome3
	LDX #1
	STX dFantome3
	JMP FinManette2
VoirFantome4Droit:
	LDA fantomeControler
	CMP #4
	BNE FinManette2
	LDX #4
	STX xyFantome4
	LDX #1
	STX dFantome4
	JMP FinManette2
FinManette2:

CompareTempsPacManBouche:
	LDA bouchePacMan			; Compare le bit de la bouche du Pac-Man
	CMP #$08					; avec un laps de temps
	BEQ ChargerPacManFermer 	; branche avec le bon chargement
	CMP #$10
	BEQ ChargerPacManOuvert	
	CMP #$18
	BEQ BouchePacManZero
	JMP FinChangementBouche		; sinon ne change rien

ChargerPacManFermer:
	LDA #0		; Cr�ation du Pac-Man ferm�
	STA $0201
	LDA #%00000000
	STA $0202
	LDA #0
	STA $0205
	LDA #%01000000
	STA $0206
	LDA #0
	STA $0209
	LDA #%10000000
	STA $020A
	LDA #0
	STA $020D
	LDA #%11000000
	STA $020E
	JMP FinChangementBouche

ChargerPacManOuvert:
	LDA sauvegardePacMan1	; Charge les donn�es du Pac-Man ouvert
	STA $0201
	LDA sauvegardePacMan2
	STA $0202
	LDA sauvegardePacMan3
	STA $0205
	LDA sauvegardePacMan4
	STA $0206
	LDA sauvegardePacMan5
	STA $0209
	LDA sauvegardePacMan6
	STA $020A
	LDA sauvegardePacMan7
	STA $020D
	LDA sauvegardePacMan8
	STA $020E
	JMP FinChangementBouche

BouchePacManZero:
	LDA #0
	STA bouchePacMan
	JMP FinChangementBouche
	
FinChangementBouche:
	
DeplaceSprites:
	INC bouchePacMan	; Incr�mente le bit de la bouche du Pac-Man
	
	; D�placement du Pac-Man
	LDX xyPacMan	
	LDA $01FF, x	; Charge la position sur l'axe x ou y selon la variable
	CLC 
	ADC dPacMan		; et y additionne le facteur de d�placement
	STA $01FF, x
	LDA $0203, x	; Recommence pour chaque Sprite du personnage
	CLC 
	ADC dPacMan
	STA $0203, x
	LDA $0207, x
	CLC 
	ADC dPacMan
	STA $0207, x
	LDA $020B, x
	CLC 
	ADC dPacMan
	STA $020B, x

	LDX xyFantome1	; D�placement du Fant�me 1
	LDA $020F, x
	CLC 
	ADC dFantome1
	STA $020F, x
	LDA $0213, x
	CLC
	ADC dFantome1
	STA $0213, x
	LDA $0217, x
	CLC 
	ADC dFantome1
	STA $0217, x
	LDA $021B, x
	CLC 
	ADC dFantome1
	STA $021B, x
	
	LDX xyFantome2	; D�placement du Fant�me 2
	LDA $021F, x
	CLC 
	ADC dFantome2
	STA $021F, x
	LDA $0223, x
	CLC
	ADC dFantome2
	STA $0223, x
	LDA $0227, x
	CLC 
	ADC dFantome2
	STA $0227, x
	LDA $022B, x
	CLC 
	ADC dFantome2
	STA $022B, x

	LDX xyFantome3	; D�placement du Fant�me 3
	LDA $022F, x
	CLC 
	ADC dFantome3
	STA $022F, x
	LDA $0233, x
	CLC
	ADC dFantome3
	STA $0233, x
	LDA $0237, x
	CLC 
	ADC dFantome3
	STA $0237, x
	LDA $023B, x
	CLC 
	ADC dFantome3
	STA $023B, x

	LDX xyFantome4	; D�placement du Fant�me 4
	LDA $023F, x
	CLC 
	ADC dFantome4
	STA $023F, x
	LDA $0243, x
	CLC
	ADC dFantome4
	STA $0243, x
	LDA $0247, x
	CLC 
	ADC dFantome4
	STA $0247, x
	LDA $024B, x
	CLC 
	ADC dFantome4
	STA $024B, x
	
	JSR PPUInit

;;---------------------------------------------------------------------------;;
;;------------------ End: Fin du NMI et retour au Forever -------------------;;
;;---------------------------------------------------------------------------;;
End:
	RTI				; Retourne au Forever � la fin du NMI

;;---------------------------------------------------------------------------;;
;;---------- PPUInit: Code d'affichage � chaque image du programme ----------;;
;;---------------------------------------------------------------------------;;
PPUInit:
	LDA #$00		; Charge $00 (0) dans A
	STA $2003		; Place A, l'octet le moins significatif ($00) dans $2003
	LDA #$02		; Charge $02 (2) dans A
	STA $4014		; Place A, l'octet le plus significatif ($02) dans $4014. 
					; Cela initie le transfert de l'adresse $0200 pour la RAM
	LDA #%10001000	; Charge les informations de contr�le du PPU dans A
	STA $2000		; Place A dans $2000
	LDA #%00011110	; Charge les informations de masque du PPU dans A
	STA $2001		; Place A dans $2001
	RTS				; Retourne � l'ex�cution parent
	
;;---------------------------------------------------------------------------;;
;;---------------- CancelScroll: D�sactive le scroll du PPU -----------------;;
;;---------------------------------------------------------------------------;;
CancelScroll:
	LDA $2002		; Lis l'�tat du PPU pour r�initialiser son latch
	LDA #$00		; Charge $00 (0) dans A
	STA $2000		; Place A dans $2000 (Scroll X pr�cis)
	STA $2006		; Place A dans $2006 (Scroll Y pr�cis)
	STA $2005		; Place A dans $2005 (Table de tuiles)
	STA $2005		; Place A dans $2005 (Scroll Y grossier)
	STA $2006		; Place A dans $2006 (Scroll X grossier)
	
;;---------------------------------------------------------------------------;;
;;------------ VBlank: Attend la fin de l'affichage d'une image -------------;;
;;---------------------------------------------------------------------------;;
VBlank:
	BIT $2002		; V�rifie le 7e bit (PPU loaded) de l'adresse $2002
	BPL VBlank		; Recommence VBlank si l'image n'est pas charg�e au complet
	RTS				; Retourne � l'ex�cution parent

;;===========================================================================;;
;;================================ Affichage ================================;;
;;===========================================================================;;

	.bank 1			; Banque 1
	.org $E000		; L'�criture commence � l'adresse $E000
	
;;---------------------------------------------------------------------------;;
;;----------- Palette: Palette de couleur du fond et des sprites ------------;;
;;---------------------------------------------------------------------------;;
Palette:
	.db $FE,$3F,$0C,$00, $00,$00,$00,$00, $00,$00,$00,$00, $00,$00,$00,$00
	; Les couleurs du fond se lisent comme suis: 
	; [Couleur de fond, Couleur 1, Couleur 2, Couleur 3], [...], ...
	.db $FE,$16,$28,$3f, $FE,$11,$00,$3f, $FE,$2A,$00,$3f, $FE,$14,$00,$3f   
	; Les couleurs des sprites se lisent comme suis: 
	; [Couleur de transparence, Couleur 1, Couleur 2, Couleur 3], [...], ...
	
;;---------------------------------------------------------------------------;;
;;---------- Sprites: Position et attribut des sprites de d�part ------------;;
;;---------------------------------------------------------------------------;;
Sprites: 
  ; Les propri�t�s des sprites se lisent comme suit:
  ; [Position Y, Index du sprite, Attributs, Position X]
  
  .db $78, 0, %00000000, $78 ; Pac-Man haut gauche
  .db $78, 1, %00000000, $80 ; Pac-Man haut droit
  .db $80, 0, %10000000, $78 ; Pac-Man bas gauche
  .db $80, 1, %10000000, $80 ; Pac-Man bas droit
  
  .db $AA, 2, %00000000, $78 ; Fant�me 1 haut gauche
  .db $AA, 2, %01000000, $80 ; Fant�me 1 haut droit
  .db $B2, 3, %00000000, $78 ; Fant�me 1 bas gauche
  .db $B2, 3, %01000000, $80 ; Fant�me 1 bas droit
  
  .db $40, 2, %00000001, $40 ; Fant�me 2 haut gauche
  .db $40, 2, %01000001, $48 ; Fant�me 2 haut droit
  .db $48, 3, %00000001, $40 ; Fant�me 2 bas gauche
  .db $48, 3, %01000001, $48 ; Fant�me 2 bas droit
  
  .db $AA, 2, %00000010, $40 ; Fant�me 3 haut gauche
  .db $AA, 2, %01000010, $48 ; Fant�me 3 haut droit
  .db $B2, 3, %00000010, $40 ; Fant�me 3 bas gauche
  .db $B2, 3, %01000010, $48 ; Fant�me 3 bas droit

  .db $40, 2, %00000011, $78 ; Fant�me 4 haut gauche
  .db $40, 2, %01000011, $80 ; Fant�me 4 haut droit
  .db $48, 3, %00000011, $78 ; Fant�me 4 bas gauche
  .db $48, 3, %01000011, $80 ; Fant�me 4 bas droit

;;===========================================================================;;
;;============================== Interruptions ==============================;;
;;===========================================================================;;

	.org $FFFA		; L'�criture commence � l'adresse $FFFA
	.dw NMI			; Lance la sous-m�thode NMI lorsque le NMI survient
	.dw Reset		; Lance la sous-m�thode Reset au d�marrage du processeur
	.dw 0			; Ne lance rien lorsque la commande BRK survient

;;===========================================================================;;
;;=============================== Background ================================;;
;;===========================================================================;;

	.bank 2			; Banque 1
	.org $0000		; L'�criture commence � l'adresse $0000
	
Fond:
	.db %01111110
	.db %10111101
	.db %11011011
	.db %11100111
	.db %11011011
	.db %10111101
	.db %01111110
	.db %11111111
	; Les pixels repr�sent�s ici sont les bits les moins significatifs

	.db %10000001
	.db %01000010
	.db %00100100
	.db %00011000
	.db %00100100
	.db %01000010
	.db %10000001
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les plus significatifs

;;===========================================================================;;
;;================================ Sprites ==================================;;
;;===========================================================================;;
	
	.org $1000		; L'�criture commence � l'adresse $1000

	; Le chiffre apr�s un nom repr�sente sa position pour un rep�rage rapide
	
PacMan0:
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les moins significatifs

	.db %00000111
	.db %00011111
	.db %00111111
	.db %00111111
	.db %01111111
	.db %01111111
	.db %11111111
	.db %11111111
	; Les pixels repr�sent�s ici sont les bits les plus significatifs

PacMan1:
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les moins significatifs

	.db %11100000
	.db %11110000
	.db %11111000
	.db %11110000
	.db %11100000
	.db %11000000
	.db %10000000
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les plus significatifs

Fantome2:
	.db %00000011
	.db %00001111
	.db %00011111
	.db %00111111
	.db %01111111
	.db %01111111
	.db %01111111
	.db %01111111
	; Les pixels repr�sent�s ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000110
	.db %00000110
	.db %00000110
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les plus significatifs

Fantome3:
	.db %01111111
	.db %01111111
	.db %01111111
	.db %01111111
	.db %01111111
	.db %01111111
	.db %01101110
	.db %01000100
	; Les pixels repr�sent�s ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les plus significatifs

PacMan4:
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels repr�sent�s ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00100000
	.db %01110000
	.db %01111000
	.db %11111100
	.db %11111110
	; Les pixels repr�sent�s ici sont les bits les plus significatifs
	
	
;;;;; La prochaine section n'est pas dans la cartouche, elle est en RAM du NES ;;;;;;
	.bank 0
	.zp				; Zero page bank (memoire rapide $0000 � $00FF).
	.org $0000
	
	; D�finition des variables ici
	
xyPacMan: .ds 1		;D�placement sur l'axe des x(4)	ou des y(1) pour un Sprite.
dPacMan: .ds 1		; La distance du d�placement d'un Sprite
xyFantome1: .ds 1
dFantome1: .ds 1
xyFantome2: .ds 1
dFantome2: .ds 1
xyFantome3: .ds 1
dFantome3: .ds 1
xyFantome4: .ds 1
dFantome4: .ds 1

fantomeControler: .ds 1		; Num�ro du Fant�me contr�l�
bouchePacMan: .ds 1			; Bit de la bouche du Pac-Man

sauvegardePacMan1: .ds 1	; Num�ros et Attributs des Sprites du Pac-Man
sauvegardePacMan2: .ds 1
sauvegardePacMan3: .ds 1
sauvegardePacMan4: .ds 1
sauvegardePacMan5: .ds 1
sauvegardePacMan6: .ds 1
sauvegardePacMan7: .ds 1
sauvegardePacMan8: .ds 1

frameCounter: .ds 1	; Le nombre de Frame (60 Hz) entre deux coups de tempo
tempoCounter: .ds 1	; Le num�ro de la note � jouer � ce coup de tempo

;;===========================================================================;;
;;============================== END OF FILE ================================;;
;;===========================================================================;;