-- ============================================================
-- PROJET : Olist E-Commerce Analytics
-- FICHIER : 03_data_dictionary.sql
-- DESCRIPTION : Dictionnaire des données + Champs d'analyse
--               définis par dashboard
-- AUTEUR : JUSTE HADASSA MALANDA NYEKELE
-- DATE : 2026
-- ============================================================


-- ============================================================
-- PARTIE 1 : DICTIONNAIRE DES DONNÉES
-- Comprendre chaque champ avant d'analyser
-- ============================================================

/*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : customers (99 441 lignes)
Rôle  : Contient les informations des acheteurs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP                  TYPE         DESCRIPTION
─────────────────────────────────────────────────────────────
customer_id            VARCHAR(50)  ID unique PAR COMMANDE
                                    ⚠️ Un client qui commande
                                    3 fois aura 3 customer_id
customer_unique_id     VARCHAR(50)  ID unique PAR CLIENT RÉEL
                                    → Utiliser pour compter
                                    les vrais clients uniques
customer_zip_code      VARCHAR(10)  Code postal brésilien
customer_city          VARCHAR(100) Ville (ex: sao paulo)
customer_state         CHAR(2)      État brésilien
                                    (ex: SP=São Paulo,
                                         RJ=Rio de Janeiro,
                                         MG=Minas Gerais)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : orders (99 441 lignes)
Rôle  : Table CENTRALE — cycle de vie de chaque commande
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP                          TYPE       DESCRIPTION
─────────────────────────────────────────────────────────────
order_id                       VARCHAR    ID unique commande
customer_id                    VARCHAR    FK → customers
order_status                   VARCHAR    Statut :
                                          • created
                                          • approved
                                          • invoiced
                                          • processing
                                          • shipped
                                          • delivered  ✅ principal
                                          • unavailable
                                          • canceled
order_purchase_timestamp       TIMESTAMP  Moment de l'achat
order_approved_at              TIMESTAMP  Paiement approuvé
order_delivered_carrier_date   TIMESTAMP  Remis au transporteur
order_delivered_customer_date  TIMESTAMP  Livré au client
order_estimated_delivery_date  TIMESTAMP  Date estimée livraison

💡 INDICATEURS CALCULABLES :
   Délai réel     = order_delivered_customer_date
                    - order_purchase_timestamp
   Délai estimé   = order_estimated_delivery_date
                    - order_purchase_timestamp
   En retard ?    = delivered_date > estimated_date
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : order_items (112 650 lignes)
Rôle  : Détail des articles dans chaque commande
        112 650 > 99 441 car certaines commandes ont
        plusieurs articles
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP               TYPE          DESCRIPTION
─────────────────────────────────────────────────────────────
order_id            VARCHAR       FK → orders
order_item_id       INT           N° article dans commande
                                  (1er article=1, 2ème=2...)
product_id          VARCHAR       FK → products
seller_id           VARCHAR       FK → sellers
shipping_limit_date TIMESTAMP     Deadline expédition vendeur
price               NUMERIC(10,2) Prix produit (HT)
                                  ⚠️ Sans les frais de port
freight_value       NUMERIC(10,2) Frais de livraison

💡 CHIFFRE D'AFFAIRES = SUM(price) + SUM(freight_value)
   ou via order_payments.payment_value
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : order_payments (103 886 lignes)
Rôle  : Modes et montants de paiement
        103 886 > 99 441 car une commande peut être payée
        avec plusieurs modes (ex: carte + voucher)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP                TYPE          DESCRIPTION
─────────────────────────────────────────────────────────────
order_id             VARCHAR       FK → orders
payment_sequential   INT           N° du paiement (1, 2...)
payment_type         VARCHAR       Mode de paiement :
                                   • credit_card  (dominant)
                                   • boleto       (virement BR)
                                   • voucher      (bon d'achat)
                                   • debit_card
payment_installments INT           Nombre de mensualités
                                   (1 = paiement comptant)
payment_value        NUMERIC(10,2) Montant payé

💡 Pour le CA total : SUM(payment_value)
   Pour les mensualités : AVG(payment_installments)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : order_reviews (99 224 lignes)
Rôle  : Satisfaction client post-livraison
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP                   TYPE         DESCRIPTION
─────────────────────────────────────────────────────────────
review_id               VARCHAR      ID unique de l'avis
order_id                VARCHAR      FK → orders
review_score            INT          Note : 1⭐ à 5⭐⭐⭐⭐⭐
review_comment_title    VARCHAR(255) Titre (souvent NULL)
review_comment_message  TEXT         Commentaire (souvent NULL)
review_creation_date    TIMESTAMP    Quand l'avis a été créé
review_answer_timestamp TIMESTAMP    Quand Olist a répondu

💡 NPS SIMPLIFIÉ :
   Score 5     → Promoteurs
   Score 3-4   → Neutres
   Score 1-2   → Détracteurs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : products (32 951 lignes)
Rôle  : Caractéristiques physiques des produits
        ⚠️ Pas de nom produit (anonymisé par Olist)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP                       TYPE          DESCRIPTION
─────────────────────────────────────────────────────────────
product_id                  VARCHAR       ID unique produit
product_category_name       VARCHAR       Catégorie (portugais)
product_name_length         INT           Longueur nom (chars)
product_description_length  INT           Longueur description
product_photos_qty          INT           Nb photos du produit
product_weight_g            NUMERIC       Poids en grammes
product_length_cm           NUMERIC       Longueur en cm
product_height_cm           NUMERIC       Hauteur en cm
product_width_cm            NUMERIC       Largeur en cm

💡 Volume (cm³) = length × height × width
   → Impacte les frais de livraison
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : sellers (3 095 lignes)
Rôle  : Informations sur les marchands tiers
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP             TYPE         DESCRIPTION
─────────────────────────────────────────────────────────────
seller_id         VARCHAR      ID unique vendeur
seller_zip_code   VARCHAR(10)  Code postal vendeur
seller_city       VARCHAR(100) Ville vendeur
seller_state      CHAR(2)      État vendeur
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TABLE : geolocation (1 000 163 lignes)
Rôle  : Coordonnées GPS par code postal brésilien
        Utilisé pour les cartes Power BI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHAMP                  TYPE         DESCRIPTION
─────────────────────────────────────────────────────────────
geolocation_zip_code   VARCHAR(10)  Code postal
geolocation_lat        NUMERIC(9,6) Latitude  (ex: -23.5489)
geolocation_lng        NUMERIC(9,6) Longitude (ex: -46.6388)
geolocation_city       VARCHAR(100) Ville
geolocation_state      CHAR(2)      État

💡 Pour les cartes : faire AVG(lat), AVG(lng)
   par zip_code pour éviter les doublons
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*/


-- ============================================================
-- PARTIE 2 : CHAMPS D'ANALYSE PAR DASHBOARD
-- ============================================================

/*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 DASHBOARD 1 — SALES PERFORMANCE
Objectif : Comprendre les revenus, tendances et produits
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

KPI PRINCIPAL
─────────────
• Chiffre d'affaires total
• Nombre total de commandes
• Panier moyen (CA / nb commandes)
• Nombre de clients uniques

DIMENSIONS D'ANALYSE
─────────────────────
• Évolution mensuelle du CA         → order_purchase_timestamp
• Top 10 catégories par revenus     → product_category_name_english
• Répartition par état brésilien    → customer_state
• Répartition modes de paiement     → payment_type
• Analyse des mensualités           → payment_installments

TABLES UTILISÉES
─────────────────
orders + order_payments + order_items + products
+ product_category_translation + customers


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚚 DASHBOARD 2 — OPERATIONS & LOGISTICS
Objectif : Mesurer la performance opérationnelle
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

KPI PRINCIPAL
─────────────
• Délai moyen de livraison (jours)
• % de commandes livrées à temps
• % de commandes en retard
• Taux de commandes annulées

DIMENSIONS D'ANALYSE
─────────────────────
• Répartition des statuts           → order_status
• Délai réel vs estimé par état     → customer_state
• Performance des vendeurs          → seller_id, seller_state
• Évolution des délais dans le temps→ order_purchase_timestamp
• Frais de port par catégorie       → freight_value

TABLES UTILISÉES
─────────────────
orders + order_items + sellers + customers


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⭐ DASHBOARD 3 — CUSTOMER EXPERIENCE
Objectif : Mesurer la satisfaction et segmenter les clients
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

KPI PRINCIPAL
─────────────
• Score moyen global (sur 5)
• % d'avis positifs (score 4-5)
• % d'avis négatifs (score 1-2)
• Taux de clients avec avis

DIMENSIONS D'ANALYSE
─────────────────────
• Distribution des scores 1→5       → review_score
• Score moyen par catégorie         → product_category_name_english
• Corrélation délai → satisfaction  → délai livraison + review_score
• Segmentation RFM clients          → Recency, Frequency, Monetary
  - Recency   : Dernière commande
  - Frequency : Nb commandes
  - Monetary  : CA total généré

TABLES UTILISÉES
─────────────────
order_reviews + orders + order_items + products
+ product_category_translation + customers + order_payments
*/


-- ============================================================
-- PARTIE 3 : EXPLORATION RAPIDE DES DONNÉES
-- Requêtes de découverte avant l'analyse
-- ============================================================

-- 3.1 Aperçu de chaque table (5 premières lignes)
SELECT * FROM customers      LIMIT 5;
SELECT * FROM orders         LIMIT 5;
SELECT * FROM order_items    LIMIT 5;
SELECT * FROM order_payments LIMIT 5;
SELECT * FROM order_reviews  LIMIT 5;
SELECT * FROM products       LIMIT 5;
SELECT * FROM sellers        LIMIT 5;


-- 3.2 Période couverte par le dataset
SELECT
    MIN(order_purchase_timestamp) AS premiere_commande,
    MAX(order_purchase_timestamp) AS derniere_commande,
    COUNT(DISTINCT DATE_TRUNC('month', order_purchase_timestamp)) AS nb_mois
FROM orders;


-- 3.3 Répartition des statuts de commandes
SELECT
    order_status,
    COUNT(*) AS nb_commandes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pourcentage
FROM orders
GROUP BY order_status
ORDER BY nb_commandes DESC;


-- 3.4 Valeurs nulles par colonne clé
SELECT
    'orders'                              AS table_name,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS nulls_delivered,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)             AS nulls_approved
FROM orders
UNION ALL
SELECT
    'order_reviews',
    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END)
FROM order_reviews;


-- 3.5 Distribution des scores d'avis
SELECT
    review_score,
    COUNT(*) AS nb_avis,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pourcentage,
    REPEAT('█', (COUNT(*) / 1000)::INT) AS barre_visuelle
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;
