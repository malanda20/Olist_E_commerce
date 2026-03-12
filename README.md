# 🛒 Olist E-Commerce Analytics — Portfolio Project

> **Analyse complète d'une marketplace brésilienne | PostgreSQL · SQL · Power BI**

[![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)](https://app.powerbi.com/view?r=eyJrIjoiNmFlZmVhYjgtYTRjOS00MjhkLWE2YTEtMjgwM2M2NTc3NTcwIiwidCI6ImI4YzE5NTEyLTJhZWQtNDcxZC1hOGQxLTliMDZlN2RhNzg2YSIsImMiOjl9)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=for-the-badge&logo=postgresql&logoColor=white)]()
[![SQL](https://img.shields.io/badge/SQL-17%20requêtes-blue?style=for-the-badge)]()
[![Dataset](https://img.shields.io/badge/Kaggle-Olist%20Dataset-20BEFF?style=for-the-badge&logo=kaggle&logoColor=white)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

## 📌 Présentation du Projet

Ce projet portfolio analyse **100 000 commandes réelles** passées entre 2016 et 2018 sur la marketplace brésilienne **Olist**. L'objectif est de répondre à trois grandes questions business à travers une démarche analytique complète : modélisation, SQL, et visualisation Power BI.

| Question | Dashboard |
|----------|-----------|
| Comment évolue le chiffre d'affaires et quelles catégories performent le mieux ? | Sales Performance |
| La logistique est-elle fiable ? Quels vendeurs sous-performent ? | Operations & Logistique |
| Les clients sont-ils satisfaits ? Quels segments cibler en priorité ? | Customer Experience & RFM |

---

## 📊 Dashboards Power BI

🔗 **[Voir les dashboards en ligne](https://app.powerbi.com/view?r=eyJrIjoiNmFlZmVhYjgtYTRjOS00MjhkLWE2YTEtMjgwM2M2NTc3NTcwIiwidCI6ImI4YzE5NTEyLTJhZWQtNDcxZC1hOGQxLTliMDZlN2RhNzg2YSIsImMiOjl9)**

### Dashboard 1 — Sales Performance
![Dashboard 1](screenshots/dashboard1_sales.png)

**KPIs :** CA Total 15,84M$ · 99K commandes · Panier moyen 160$ · 96K clients uniques

**Insights clés :**
- Croissance x9 en 2017, pic Black Friday novembre +53,6%
- `health_beauty` est la catégorie n°1 avec 1,44M$ de CA
- São Paulo représente 37% du CA national
- Paiement en 7-12 mensualités → panier moyen x3,5 vs paiement comptant

---

### Dashboard 2 — Operations & Logistique
![Dashboard 2](screenshots/dashboard2_operations.png)

**KPIs :** Délai réel 12,5j · Délai estimé 24,4j · Écart -11,9j · Ponctualité 91,89%

**Insights clés :**
- Stratégie de sur-promesse délibérée et efficace : livraison 12j avant la promesse
- Les états du nord amazonien (RR, AP, AM) ont des délais 3x plus longs que SP
- Anomalie détectée : l'Alagoas (AL) présente 23,9% de retard malgré une distance modérée
- Les pires vendeurs sont à São Paulo — problème opérationnel, pas géographique

> ⚠️ **Bug connu :** La matrice Top/Flop vendeurs affiche des valeurs identiques pour tous les vendeurs (Délai : 2,71j, Taux retard : 0,08). Ce comportement est causé par une perte de contexte de filtre dans les mesures DAX — la correction est documentée ci-dessous.

---

### Dashboard 3 — Customer Experience & RFM
*En cours de construction*

---

## 🐛 Bug documenté — Matrice Vendeurs (Dashboard 2)

### Symptôme
La matrice affiche les mêmes valeurs pour chaque vendeur :

| seller_city | Délai Expédition | Taux Retard % |
|-------------|-----------------|---------------|
| São Paulo   | **2,71**        | **0,08**      |
| Curitiba    | **2,71**        | **0,08**      |
| Americana   | **2,71**        | **0,08**      |

### Cause
Les mesures sont calculées sur la table `orders`, mais le contexte de filtre de la matrice (par `seller_city`) ne se propage pas jusqu'à `orders` via `order_items` → `sellers`. Power BI évalue les mesures au niveau global, ignorant le filtre vendeur.

### Correction DAX

```dax
-- AVANT (problématique)
Délai Expédition Vendeur (jours) =
AVERAGEX(
    FILTER(orders, orders[order_approved_at] <> BLANK()),
    DATEDIFF(orders[order_approved_at], orders[order_delivered_carrier_date], DAY)
)

-- APRÈS (corrigé — contexte de filtre via order_items)
Délai Expédition Vendeur (jours) =
AVERAGEX(
    FILTER(
        order_items,
        RELATED(orders[order_approved_at]) <> BLANK() &&
        RELATED(orders[order_delivered_carrier_date]) <> BLANK()
    ),
    DATEDIFF(
        RELATED(orders[order_approved_at]),
        RELATED(orders[order_delivered_carrier_date]),
        DAY
    )
)
```

```dax
-- Taux Retard % corrigé
Taux Retard % =
VAR total =
    CALCULATE(
        COUNTROWS(orders),
        orders[order_status] = "delivered",
        orders[order_delivered_customer_date] <> BLANK()
    )
VAR en_retard =
    CALCULATE(
        COUNTROWS(orders),
        orders[order_status] = "delivered",
        orders[order_delivered_customer_date] > orders[order_estimated_delivery_date]
    )
RETURN DIVIDE(en_retard, total, 0)
```

### Leçon apprise
> En Power BI, une mesure calculée dans une table "parent" (`orders`) ne reçoit pas automatiquement le filtre d'une table "enfant" (`sellers`). Il faut ancrer la mesure dans la table qui porte la relation directe avec le contexte de filtre (`order_items`), puis remonter via `RELATED()`.

---

## 🗂️ Structure du Projet

```
olist_sql_projet/
│
├── 01_create_tables.sql          # Création des 9 tables
├── 02_import_data.sql            # Import des CSV + vérifications
├── 03_data_dictionary.sql        # Dictionnaire de données
├── 04_analysis_sales.sql         # 6 requêtes Dashboard 1
├── 05_analysis_operations.sql    # 5 requêtes Dashboard 2
├── 06_analysis_customer_experience.sql  # 6 requêtes Dashboard 3 + RFM
│
├── Olist_ecommerce.pbix          # Fichier Power BI
└── README.md
```

---

## 🗃️ Dataset & Modèle de Données

**Source :** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle

| Table | Lignes | Description |
|-------|--------|-------------|
| orders | 99 441 | Commandes avec statuts et timestamps |
| order_items | 112 650 | Produits par commande |
| order_payments | 103 886 | Paiements (type, montant, mensualités) |
| order_reviews | 99 224 | Avis clients (note 1-5) |
| customers | 99 441 | Clients (ville, état) |
| sellers | 3 095 | Vendeurs (ville, état) |
| products | 32 951 | Catalogue produits |
| geolocation | 1 000 163 | Coordonnées GPS |
| product_category_translation | 71 | Traduction PT → EN |

**Modèle en étoile :** `orders` au centre, reliée à toutes les tables de dimension via les clés `order_id`, `customer_id`, `product_id`, `seller_id`.

---

## 💡 Principaux Résultats

| # | Insight | Impact |
|---|---------|--------|
| 1 | Croissance x9 du CA en 2017, plateau ~1M$/mois en 2018 | Plateforme mature |
| 2 | 96K commandes pour 96K clients — rétention quasi nulle | Modèle acquisition |
| 3 | Livraison 12j avant la promesse — sur-promesse intentionnelle | 91,9% ponctualité |
| 4 | Retard >3j → note chute de 4,27 à 2,11 (-44%) | Effet falaise critique |
| 5 | NPS = 43 — comparable aux grandes plateformes | Satisfaction solide |
| 6 | 2,1M$ de CA en danger (segment "Presque perdus", récence 418j) | Réactivation urgente |
| 7 | Paiement 7-12 mensualités → panier x3,5 vs comptant | Levier CA majeur |

---

## 🛠️ Stack Technique

- **PostgreSQL 16** — Stockage et modélisation relationnelle
- **SQL** — 17 requêtes analytiques (agrégations, fenêtrages, CTEs, RFM)
- **Python** — Nettoyage encodage UTF-8/Latin-1 du fichier `order_reviews`
- **Power BI Desktop** — 2 dashboards interactifs publiés (3ème en cours)
- **DAX** — Mesures calculées, colonnes calculées, segmentation RFM

---

## 👩‍💻 Auteure

**Juste Hadassa MALANDA NYEKELE**
Data Analyst — Mars 2026

---

*Ce projet fait partie de mon portfolio Data Analytics.*
