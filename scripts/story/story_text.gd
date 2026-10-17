class_name StoryText
extends RefCounted
## Tutti i dialoghi originali della storia "La valigetta del Corvo".
## Ogni riga: [chi parla, testo].

const INTRO_FLIGHT := [
	["narrator", "Volo AR-77, 9.000 metri sopra l'oceano. Destinazione: Capo Serena."],
	["tom", "Ricapitoliamo. Consegniamo la valigetta a Silas Crane, incassiamo e nessuno fa domande."],
	["mike", "Rilassati, Tom. È il lavoro più facile della nostra vita."],
	["norman", "Ogni volta che lo dici, qualcosa va storto."],
	["mike", "Dex ci ha garantito che è tutto pulito. E Dex non sbaglia mai."],
]
const INTRO_INCIDENT := [
	["narrator", "BOOM. Il motore sinistro prende fuoco. L'aereo sbanda."],
	["pilot", "Signori, abbiamo un guasto al motore! Atterraggio d'emergenza a Port Ardena!"],
	["mike", "Port Ardena? Non era nel piano!"],
	["norman", "Tenetevi forte!"],
]
const INTRO_LANDING := [
	["narrator", "Pista di Port Ardena. L'aereo si ferma tra fumo e sirene."],
	["norman", "...Tom. La valigetta."],
	["tom", "Era nel vano bagagli sopra di noi. È sparita!"],
	["narrator", "Al suo posto: una piuma nera e un biglietto. \"Il Corvo vola sempre da solo.\""],
	["mike", "Qualcuno su quell'aereo ci ha appena fregati."],
	["tom", "Crane ci darà la caccia. Dobbiamo ritrovarla prima di lui."],
	["norman", "Noi prendiamo un taxi per il rifugio. Mike, sei ferito: rimettiti in sesto e raggiungici."],
]

const M1_END := [
	["tom", "Eccolo, finalmente. Benvenuto nel nostro nuovo rifugio."],
	["mike", "Bel posto. Un po' di polvere, ma ho visto di peggio."],
	["norman", "Qui possiamo salvare i progressi e riposare. Il pavimento verde lì fuori, vicino alla porta."],
	["tom", "Ora serve un piano. E un'auto: a piedi questa città è enorme."],
]
const M2_INTRO := [
	["norman", "Senza un'auto in questa città non andiamo da nessuna parte."],
	["mike", "Lasciate fare a me. C'è un parcheggio qui vicino, a ovest."],
	["tom", "Niente follie. Portala al garage di Gus, è un vecchio amico."],
]
const M2_END := [
	["gus", "Mike Vargo! Sempre al volante di auto più belle di te. Benvenuti nel mio garage."],
	["mike", "Ci serve un posto tranquillo, Gus. E qualche domanda senza risposte."],
	["gus", "Qui siete al sicuro. Fuori dal garage troverete sempre un'auto pronta per voi."],
]
const M3_INTRO := [
	["narrator", "Il telefono squilla. Numero sconosciuto."],
	["lenny", "Mi chiamano Lenny \"Fumo\". So chi ha preso la vostra valigetta."],
	["lenny", "Ma le informazioni costano. Al porto c'è un pacco a mio nome: portamelo in Piazza del Corvo."],
	["tom", "Potrebbe essere una trappola."],
	["mike", "Potrebbe. Ma è l'unica pista che abbiamo."],
]
const M3_END := [
	["lenny", "Puntuali. Mi piace."],
	["lenny", "Ecco il regalo: chi ha preso la valigetta si fa chiamare \"il Corvo\". Lavora con le Vipere."],
	["mike", "Le Vipere?"],
	["lenny", "La banda che comanda il porto. E... mi hanno pagato bene per trattenervi qui. Niente di personale."],
	["narrator", "Rombo di motori. Tre auto nere svoltano verso la piazza."],
]
const M4_INTRO := [
	["norman", "Sono le Vipere! Trova un'auto e seminale, subito!"],
]
const M4_END := [
	["tom", "Ci hanno teso una trappola. Tornate al rifugio: ho bisogno di pensare."],
	["tom", "E... bella guida."],
]
const M5_INTRO := [
	["tom", "Il Corvo sapeva tutto del nostro volo. Qualcuno gli ha passato le informazioni."],
	["tom", "Ci sono quattro indizi: il manifesto di volo, il video della sicurezza, una ricevuta del porto e un telefono."],
	["tom", "Ogni indizio è sorvegliato da telecamere. Se mi vedono troppo a lungo scatta l'allarme."],
	["tom", "Per fortuna ho la mia ANALISI: disattiva le telecamere vicine per qualche secondo."],
]
const M5_END := [
	["tom", "Il manifesto di volo: un posto prenotato a nome D. Morlan. Pagato dallo stesso conto della ricevuta del porto."],
	["mike", "Dex Morlan? Il nostro intermediario? È lui che ci ha procurato il lavoro!"],
	["tom", "E il video mostra il copilota che gli passa un biglietto prima del finto guasto. Dex è il Corvo."],
	["norman", "Allora gli faccio una visita."],
	["tom", "Non ancora. La valigetta è in un magazzino delle Vipere. Il codice d'accesso lo ha il loro pilota migliore: Razor."],
	["tom", "E Razor stasera corre una gara clandestina. Mike, tocca a te: vediamoci al garage."],
]
const M6_INTRO := [
	["mike", "Una gara clandestina? Finalmente parliamo la mia lingua."],
	["razor", "Così tu sei Vargo. Le regole sono semplici: segui i checkpoint e arriva prima che scada il tempo."],
	["razor", "Se vinci, il codice del magazzino è tuo. Ti ho preparato una Vortex. Non graffiarla."],
]
const M6_WIN := [
	["razor", "Impossibile... nessuno mi aveva mai battuto. Il codice è 7-4-1-9."],
	["mike", "Tom, abbiamo il codice. Norman, tocca a te: il magazzino è pieno di Vipere."],
]
const M6_LOSE := [
	["razor", "Non male, Vargo, ma io sono arrivato prima. Tieni comunque il codice: 7-4-1-9. Dex non mi è mai piaciuto."],
	["mike", "Tom, abbiamo il codice. Norman, tocca a te: il magazzino è pieno di Vipere."],
]
const M7_INTRO := [
	["norman", "Il magazzino delle Vipere. Mike, Tom: restate fuori. Questa è roba mia."],
	["tom", "Ci sono almeno dodici uomini là dentro, Norman."],
	["norman", "Allora ne avanzeranno pochi."],
]
const M7_END := [
	["norman", "...Il magazzino è vuoto. C'è solo un biglietto."],
	["dex", "\"Troppo lenti, ragazzi. Il Corvo vola stanotte. -D.\""],
	["norman", "Dex sta scappando dall'aeroporto. Ci vediamo al rifugio: finiamo questa storia."],
]
const M8_INTRO := [
	["tom", "Dex ha un jet privato all'hangar 2. Se decolla, la valigetta sparisce per sempre."],
	["mike", "Allora non decollerà."],
	["norman", "Chi ci va?"],
]
const M8_CHOICE := {
	"mike": [["mike", "Io. Nessuno guida come me: lo raggiungo prima che accenda i motori."]],
	"tom": [["tom", "Io. Ho già hackerato i sistemi della torre: avrò più tempo e Dex sarà più lento."]],
	"norman": [["norman", "Io. Dex mi deve delle spiegazioni... e i suoi gorilla mi devono un ballo."]],
}
const M8_DEX := [
	["dex", "Ragazzi! Che sorpresa. Peccato che io abbia un aereo da prendere."],
]
const M8_END := [
	["dex", "Aspettate... non capite. Crane vi avrebbe fatti sparire comunque, dopo la consegna."],
	["tom", "Apriamola."],
	["narrator", "Dentro la valigetta: un registro nero, pieno di nomi, cifre e firme."],
	["tom", "Il Libro Nero di Silas Crane. Tangenti, ricatti: mezza Port Ardena sul suo libro paga."],
	["mike", "Quindi il vero tradimento era il lavoro stesso. Crane voleva usarci come corrieri e poi farci sparire."],
	["norman", "E Dex voleva venderlo al miglior offerente."],
	["dex", "Il Corvo vola sempre da solo... avrei dovuto ricordarmelo."],
	["tom", "Il Libro va alla stampa. Domani tutta la città saprà chi è Silas Crane."],
	["mike", "E noi?"],
	["norman", "Noi ci prendiamo una vacanza. In macchina. Niente aerei."],
]
