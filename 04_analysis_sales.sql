-- ============================================================
-- PROJET : Olist E-Commerce Analytics
-- FICHIER : 04_analysis_sales.sql
-- DASHBOARD : 1 — Sales Performance
-- DESCRIPTION : Requêtes analytiques sur les ventes,
--               tendances et catégories de produits
-- AUTEUR : [Ton nom]
-- DATE : 2024
-- ============================================================
-- TABLES UTILISÉES :
--   orders                      → statut, dates
--   order_payments              → montants, modes de paiement
--   order_items                 → prix, frais de port
--   products                    → catégories
--   product_category_translation→ traduction PT → EN
--   customers                   → localisation
-- ============================================================


-- ============================================================
-- Q1 : KPIs GLOBAUX
-- Question business : Quelle est la performance globale
--                     de la plateforme Olist ?
--
-- LOGIQUE :
--   - On filtre sur order_status = 'delivered' uniquement
--     car ce sont les commandes réellement finalisées
--   - CA = somme des paiements réels (order_payments)
--   - Panier moyen = CA total / nombre de commandes
--   - customer_unique_id pour compter les VRAIS clients
--     (pas customer_id qui change à chaque commande)
-- ============================================================
SELECT
    -- Chiffre d'affaires total
    ROUND(SUM(op.payment_value)::NUMERIC, 2)                    AS ca_total,

    -- Nombre de commandes livrées
    COUNT(DISTINCT o.order_id)                                   AS nb_commandes,

    -- Panier moyen par commande
    ROUND(AVG(op.payment_value)::NUMERIC, 2)                    AS panier_moyen,

    -- Nombre de clients uniques (vrais clients, pas doublons)
    COUNT(DISTINCT c.customer_unique_id)                         AS nb_clients_uniques,

    -- CA moyen par client
    ROUND(
        SUM(op.payment_value) /
        COUNT(DISTINCT c.customer_unique_id)::NUMERIC, 2
    )                                                            AS ca_par_client

FROM orders o
JOIN order_payments op  ON o.order_id   = op.order_id
JOIN customers c        ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';


-- ============================================================
-- Q2 : ÉVOLUTION MENSUELLE DU CA
-- Question business : Comment les ventes évoluent-elles
--                     dans le temps ? Y a-t-il une saisonnalité ?
--
-- LOGIQUE :
--   - DATE_TRUNC('month', ...) regroupe toutes les dates
--     d'un même mois en une seule valeur
--     Ex: 2017-01-15 et 2017-01-28 → 2017-01-01
--   - On calcule la croissance mois/mois avec LAG()
--     LAG() = fonction fenêtre qui récupère la valeur
--     du mois PRÉCÉDENT dans la même colonne
--   - TO_CHAR() formate la date pour l'affichage
-- ============================================================
WITH ca_mensuel AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)  AS mois,
        ROUND(SUM(op.payment_value)::NUMERIC, 2)         AS ca_mensuel,
        COUNT(DISTINCT o.order_id)                        AS nb_commandes
    FROM orders o
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    TO_CHAR(mois, 'YYYY-MM')                             AS mois,
    ca_mensuel,
    nb_commandes,

    -- CA du mois précédent (pour calculer la croissance)
    LAG(ca_mensuel) OVER (ORDER BY mois)                 AS ca_mois_precedent,

    -- Croissance en % vs mois précédent
    ROUND(
        (ca_mensuel - LAG(ca_mensuel) OVER (ORDER BY mois))
        / NULLIF(LAG(ca_mensuel) OVER (ORDER BY mois), 0)
        * 100, 1
    )                                                    AS croissance_pct

FROM ca_mensuel
ORDER BY mois;

-- 💡 CE QU'ON CHERCHE DANS LES RÉSULTATS :
--    • Une tendance haussière générale (croissance e-commerce BR)
--    • Des pics en novembre (Black Friday brésilien)
--    • Des creux en début d'année


-- ============================================================
-- Q3 : TOP 10 CATÉGORIES PAR REVENUS
-- Question business : Quels types de produits génèrent
--                     le plus de chiffre d'affaires ?
--
-- LOGIQUE :
--   - On joint products → product_category_translation
--     pour avoir les noms en anglais
--   - COALESCE() = "prends la traduction anglaise si elle
--     existe, sinon garde le nom portugais original"
--   - On calcule 3 métriques par catégorie :
--     revenus, nb commandes, prix moyen
-- ============================================================
SELECT
    -- Nom de catégorie en anglais (ou portugais si pas de trad.)
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Non catégorisé'
    )                                                    AS categorie,

    -- Revenus totaux de la catégorie
    ROUND(SUM(oi.price)::NUMERIC, 2)                    AS revenus_total,

    -- Nombre de commandes contenant cette catégorie
    COUNT(DISTINCT oi.order_id)                          AS nb_commandes,

    -- Prix moyen d'un produit dans cette catégorie
    ROUND(AVG(oi.price)::NUMERIC, 2)                    AS prix_moyen,

    -- Part des revenus totaux (%)
    ROUND(
        SUM(oi.price) * 100.0 /
        SUM(SUM(oi.price)) OVER ()
    , 2)                                                 AS part_revenus_pct

FROM order_items oi
JOIN orders o       ON oi.order_id   = o.order_id
JOIN products p     ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
                    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Non catégorisé'
    )
ORDER BY revenus_total DESC
LIMIT 10;

-- 💡 CE QU'ON CHERCHE :
--    • Les catégories "vaches à lait" (fort CA)
--    • Écart entre prix moyen et volume (niche vs masse)


-- ============================================================
-- Q4 : REVENUS PAR ÉTAT BRÉSILIEN
-- Question business : Quelles régions du Brésil sont
--                     les plus actives sur la plateforme ?
--
-- LOGIQUE :
--   - customer_state = état de LIVRAISON (où est le client)
--   - On calcule CA, nb commandes et panier moyen par état
--   - RANK() classe les états du plus au moins performant
-- ============================================================
SELECT
    c.customer_state                                     AS etat,
    COUNT(DISTINCT o.order_id)                           AS nb_commandes,
    ROUND(SUM(op.payment_value)::NUMERIC, 2)            AS ca_total,
    ROUND(AVG(op.payment_value)::NUMERIC, 2)            AS panier_moyen,

    -- Rang par CA (1 = meilleur état)
    RANK() OVER (ORDER BY SUM(op.payment_value) DESC)    AS rang,

    -- Part du CA total national (%)
    ROUND(
        SUM(op.payment_value) * 100.0 /
        SUM(SUM(op.payment_value)) OVER ()
    , 2)                                                 AS part_ca_national_pct

FROM orders o
JOIN customers c        ON o.customer_id  = c.customer_id
JOIN order_payments op  ON o.order_id     = op.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY ca_total DESC;

-- 💡 CE QU'ON CHERCHE :
--    • SP (São Paulo) devrait dominer largement
--    • Comparer nb_commandes vs CA → panier moyen élevé ?
--    • États avec peu de commandes mais gros panier moyen


-- ============================================================
-- Q5 : RÉPARTITION DES MODES DE PAIEMENT
-- Question business : Comment les clients paient-ils ?
--                     Quel impact sur le CA ?
--
-- LOGIQUE :
--   - payment_type contient : credit_card, boleto,
--     voucher, debit_card
--   - Une commande peut avoir PLUSIEURS paiements
--     (ex: carte + voucher) → on groupe par payment_type
--   - payment_installments > 1 = achat à crédit
-- ============================================================
SELECT
    payment_type                                          AS mode_paiement,
    COUNT(*)                                              AS nb_transactions,
    ROUND(SUM(payment_value)::NUMERIC, 2)                AS montant_total,
    ROUND(AVG(payment_value)::NUMERIC, 2)                AS montant_moyen,

    -- Part en % du nombre de transactions
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
    , 2)                                                  AS part_transactions_pct,

    -- Part en % du CA total
    ROUND(
        SUM(payment_value) * 100.0 /
        SUM(SUM(payment_value)) OVER ()
    , 2)                                                  AS part_ca_pct

FROM order_payments op
JOIN orders o ON op.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY payment_type
ORDER BY montant_total DESC;

-- 💡 CE QU'ON CHERCHE :
--    • La carte de crédit devrait être dominante au Brésil
--    • Le boleto = virement bancaire brésilien (sans banque)
--    • Comparer montant_moyen entre les modes de paiement


-- ============================================================
-- Q6 : ANALYSE DES MENSUALITÉS (INSTALLMENTS)
-- Question business : Les clients achètent-ils à crédit ?
--                     Quel est l'impact sur le panier moyen ?
--
-- LOGIQUE :
--   - payment_installments = nombre de fois que le client
--     paie (1 = comptant, 12 = 12 mensualités)
--   - On regroupe par tranche pour voir la distribution
--   - Un panier moyen plus élevé en mensualités montre que
--     le crédit permet d'acheter plus cher
-- ============================================================
SELECT
    -- Regroupement en tranches de mensualités
    CASE
        WHEN payment_installments = 1  THEN '1 - Comptant'
        WHEN payment_installments <= 3 THEN '2-3 mensualités'
        WHEN payment_installments <= 6 THEN '4-6 mensualités'
        WHEN payment_installments <= 12 THEN '7-12 mensualités'
        ELSE '12+ mensualités'
    END                                                   AS tranche_mensualites,

    COUNT(*)                                              AS nb_transactions,
    ROUND(AVG(payment_value)::NUMERIC, 2)                AS panier_moyen,
    ROUND(SUM(payment_value)::NUMERIC, 2)                AS ca_total,

    -- Part en % du nombre de transactions
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
    , 2)                                                  AS part_pct

FROM order_payments op
JOIN orders o ON op.order_id = o.order_id
WHERE o.order_status    = 'delivered'
  AND payment_type      = 'credit_card'   -- Mensualités = carte de crédit uniquement
GROUP BY
    CASE
        WHEN payment_installments = 1  THEN '1 - Comptant'
        WHEN payment_installments <= 3 THEN '2-3 mensualités'
        WHEN payment_installments <= 6 THEN '4-6 mensualités'
        WHEN payment_installments <= 12 THEN '7-12 mensualités'
        ELSE '12+ mensualités'
    END
ORDER BY MIN(payment_installments);

-- 💡 CE QU'ON CHERCHE :
--    • Plus les mensualités sont élevées → panier moyen plus grand
--    • Quelle tranche représente le plus de transactions ?
--    • Les achats en 1x sont-ils les plus fréquents ?


-- ============================================================
-- RÉCAPITULATIF — Ce que ce fichier produit
-- ============================================================
/*
Q1 → 1 ligne   : KPIs globaux (CA, commandes, panier moyen, clients)
Q2 → ~25 lignes : CA et croissance mois par mois
Q3 → 10 lignes  : Top catégories par revenus
Q4 → ~27 lignes : Performance par état brésilien
Q5 → 4 lignes   : Répartition modes de paiement
Q6 → 5 lignes   : Distribution des mensualités carte de crédit

→ Ces 6 résultats alimenteront directement Power BI Dashboard 1
*/
