from fpdf import FPDF
import datetime

def clean_text(text):
    replacements = {
        '’': "'", 'é': 'e', 'è': 'e', 'à': 'a', 'ç': 'c', 'ê': 'e', 'î': 'i', 'ô': 'o', 'ù': 'u', 'ï': 'i'
    }
    for k, v in replacements.items():
        text = text.replace(k, v)
    return text.encode('latin-1', 'replace').decode('latin-1')

class PDF(FPDF):
    def header(self):
        self.set_font('Arial', 'B', 12)
        self.cell(0, 10, clean_text('TriDéchet - Expertise Technique Frontend'), 0, 1, 'R')
        self.line(10, 18, 200, 18)

    def chapter_title(self, label):
        self.set_font('Arial', 'B', 14)
        self.set_fill_color(46, 204, 113)
        self.set_text_color(255, 255, 255)
        self.cell(0, 10, clean_text(f" {label}"), 0, 1, 'L', 1)
        self.set_text_color(0, 0, 0)
        self.ln(5)

    def section_title(self, label):
        self.set_font('Arial', 'B', 12)
        self.set_text_color(39, 174, 96)
        self.cell(0, 8, clean_text(label), 0, 1, 'L')
        self.set_text_color(0, 0, 0)

pdf = PDF()
pdf.alias_nb_pages()
pdf.add_page()

# Cover
pdf.ln(60)
pdf.set_font('Arial', 'B', 32)
pdf.cell(0, 20, 'TriDechet Mobile', 0, 1, 'C')
pdf.set_font('Arial', '', 18)
pdf.cell(0, 10, 'Vision Multi-Acteurs & Logistique', 0, 1, 'C')
pdf.ln(20)
pdf.set_font('Arial', 'I', 12)
pdf.cell(0, 10, f'Par : [Votre Nom] - {datetime.date.today()}', 0, 1, 'C')
pdf.add_page()

# Intro
pdf.chapter_title("1. Conformite aux Besoins Fonctionnels")
pdf.set_font('Arial', '', 11)
pdf.multi_cell(0, 6, clean_text("L'application a ete developpee pour repondre aux exigences strictes du cahier des charges, en couvrant l'integralite des acteurs de la chaine de valeur du recyclage."))

# Acteurs
pdf.section_title("A. Les Acteurs Terrain")
pdf.multi_cell(0, 6, clean_text("- Utilisateur : Acces aux quiz, formations et suivi de performance (Eco-points).\n- Educateur : Animation de sessions et guides pedagogiques.\n- Gestionnaire de points : Traitement des signalements (bacs pleins) et cartographie."))

pdf.section_title("B. Focus : Prestataire de Collecte")
pdf.set_font('Arial', 'B', 11)
pdf.multi_cell(0, 6, clean_text("Role crucial pour la boucle de valorisation :"))
pdf.set_font('Arial', '', 11)
pdf.multi_cell(0, 6, clean_text("- Logistique & Transport : Optimisation des tournees de ramassage via un planning dynamique.\n- Orientation des flux : Interface de selection pour diriger les flux collectes vers soit la filiere 'RECYCLAGE' (matieres), soit la filiere 'VALORISATION' (energie/compost)."))

# Technique
pdf.add_page()
pdf.chapter_title("2. Architecture Technique")
pdf.section_title("Developpement Flutter Pro")
pdf.multi_cell(0, 6, clean_text("L'architecture utilise un systeme de 'Navigation Shell' qui adapte l'interface en temps reel selon le role connecte (Admin, Collecteur, etc.). Cela garantit une securite maximale des donnees."))
pdf.set_font('Courier', '', 9)
pdf.set_fill_color(240, 240, 240)
pdf.multi_cell(0, 5, clean_text("""// Exemple de separation des responsabilites
switch (user.role) {
  case UserRole.collector:
    return CollectorTab(); // Gestion des tournees et orientation
  case UserRole.user:
    return FeedTab(); // Contenus et Quiz
}"""), 1, 'L', True)

pdf.ln(10)
pdf.chapter_title("3. Conclusion")
pdf.set_font('Arial', '', 11)
pdf.multi_cell(0, 6, clean_text("L'application est prete pour un deploiement reel. Elle couvre non seulement la sensibilisation (Front-office) mais aussi la logistique metier (Back-office) indispensable a une gestion de territoire moderne."))

pdf.output("Rapport_Demonstration_TriDechet.pdf")
print("Rapport final genere avec succes !")
