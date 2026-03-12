-- ============================================================
-- PROJET : Olist E-Commerce Analytics
-- FICHIER : 06_analysis_customer_experience.sql
-- DASHBOARD : 3 — Customer Experience
-- DESCRIPTION : Satisfaction client, analyse des avis,
--               corrélation délais/notes, segmentation RFM
-- AUTEUR : JUSTE HADASSA MALANDA NYEKELE
-- DATE : 2026
-- ============================================================
-- TABLES UTILISÉES :
--   order_reviews               → notes et commentaires
--   orders                      → dates et statuts
--   order_items                 → produits commandés
--   products                    → catégories
--   product_category_translation→ traduction PT → EN
--   order_payments              → montants dépensés
--   customers                   → identité client unique
-- ============================================================


-- ============================================================
-- Q1 : SATISFACTION GLOBALE — KPIs et NPS Simplifié
-- Question business : Les clients sont-ils satisfaits
--                     de leur expérience sur Olist ?
--
-- LOGIQUE :
--   Score moyen sur 5 = indicateur général
--
--   NPS simplifié (Net Promoter Score) :
--   • Promoteurs   = score 5       (recommandent la plateforme)
--   • Neutres      = score 3-4     (ni pour ni contre)
--   • Détracteurs  = score 1-2     (insatisfaits, bouche à oreille négatif)
--
--   NPS = % Promoteurs - % Détracteurs
--   Un NPS > 0 est positif, > 50 est excellent
-- ============================================================
WITH scores AS (
    SELECT
        review_score,
        COUNT(*)                                        AS nb_avis,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
    FROM order_reviews
    WHERE review_score IS NOT NULL
    GROUP BY review_score
),
nps_calc AS (
    SELECT
        SUM(CASE WHEN review_score = 5      THEN pct ELSE 0 END) AS pct_promoteurs,
        SUM(CASE WHEN review_score IN (3,4) THEN pct ELSE 0 END) AS pct_neutres,
        SUM(CASE WHEN review_score IN (1,2) THEN pct ELSE 0 END) AS pct_detracteurs
    FROM scores
)
SELECT
    -- Score moyen global
    ROUND(AVG(r.review_score)::NUMERIC, 2)             AS score_moyen,

    -- Nombre total d'avis
    COUNT(r.review_id)                                  AS nb_avis_total,

    -- Distribution par note
    SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) AS nb_score_5,
    SUM(CASE WHEN r.review_score = 4 THEN 1 ELSE 0 END) AS nb_score_4,
    SUM(CASE WHEN r.review_score = 3 THEN 1 ELSE 0 END) AS nb_score_3,
    SUM(CASE WHEN r.review_score = 2 THEN 1 ELSE 0 END) AS nb_score_2,
    SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS nb_score_1,

    -- NPS simplifié
    ROUND((SELECT pct_promoteurs  FROM nps_calc), 1)   AS pct_promoteurs,
    ROUND((SELECT pct_neutres     FROM nps_calc), 1)   AS pct_neutres,
    ROUND((SELECT pct_detracteurs FROM nps_calc), 1)   AS pct_detracteurs,
    ROUND((SELECT pct_promoteurs - pct_detracteurs
           FROM nps_calc), 1)                          AS nps_score

FROM order_reviews r
WHERE r.review_score IS NOT NULL;

-- 💡 CE QU'ON CHERCHE :
--    • Score moyen > 4 = très bon
--    • NPS > 0 = plus de promoteurs que détracteurs
--    • Dominance des 5 étoiles (souvent 50%+ en e-commerce)


-- ============================================================
-- Q2 : SATISFACTION PAR CATÉGORIE DE PRODUIT
-- Question business : Certaines catégories génèrent-elles
--                     systématiquement de l'insatisfaction ?
--
-- LOGIQUE :
--   On joint reviews → orders → order_items → products
--   pour relier chaque avis à sa catégorie de produit
--   HAVING COUNT > 100 = seulement les catégories
--   avec assez d'avis pour être statistiquement fiables
-- ============================================================
SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Non catégorisé'
    )                                                   AS categorie,

    COUNT(r.review_id)                                  AS nb_avis,
    ROUND(AVG(r.review_score)::NUMERIC, 2)             AS note_moyenne,

    -- Répartition positif / négatif
    ROUND(SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                         AS pct_avis_positifs,

    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                         AS pct_avis_negatifs,

    -- Rang du meilleur au moins bon
    RANK() OVER (ORDER BY AVG(r.review_score) DESC)    AS rang

FROM order_reviews r
JOIN orders o       ON r.order_id    = o.order_id
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN products p     ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
                    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
  AND r.review_score IS NOT NULL
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Non catégorisé'
    )
HAVING COUNT(r.review_id) > 100
ORDER BY note_moyenne DESC;

-- 💡 CE QU'ON CHERCHE :
--    • Top 5 catégories les mieux notées
--    • Flop 5 catégories les moins bien notées
--    • % avis négatifs élevé = problème qualité produit


-- ============================================================
-- Q3 : CORRÉLATION DÉLAI DE LIVRAISON → SATISFACTION
-- Question business : Un client livré en retard
--                     donne-t-il forcément une mauvaise note ?
--
-- LOGIQUE :
--   On calcule l'écart entre livraison réelle et estimée
--   Puis on groupe par tranche d'écart et on mesure
--   la note moyenne dans chaque tranche
--   C'est une analyse de corrélation simple mais puissante
-- ============================================================
WITH livraisons AS (
    SELECT
        o.order_id,
        r.review_score,

        -- Écart en jours (négatif = en avance, positif = retard)
        ROUND(
            EXTRACT(EPOCH FROM (
                o.order_delivered_customer_date - o.order_estimated_delivery_date
            )) / 86400
        , 0)                                            AS ecart_jours

    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND r.review_score IS NOT NULL
)
SELECT
    -- Tranches d'écart lisibles
    CASE
        WHEN ecart_jours < -10 THEN 'Très en avance (>10j avant)'
        WHEN ecart_jours < -3  THEN 'En avance (3-10j avant)'
        WHEN ecart_jours < 0   THEN 'Légèrement en avance (1-3j)'
        WHEN ecart_jours = 0   THEN 'À temps (jour J)'
        WHEN ecart_jours <= 3  THEN 'Léger retard (1-3j)'
        WHEN ecart_jours <= 10 THEN 'Retard modéré (3-10j)'
        ELSE                        'Retard important (>10j)'
    END                                                 AS tranche_ecart,

    COUNT(*)                                            AS nb_commandes,
    ROUND(AVG(review_score)::NUMERIC, 2)               AS note_moyenne,

    -- Distribution des notes dans cette tranche
    ROUND(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                         AS pct_notes_positives,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                         AS pct_notes_negatives

FROM livraisons
GROUP BY
    CASE
        WHEN ecart_jours < -10 THEN 'Très en avance (>10j avant)'
        WHEN ecart_jours < -3  THEN 'En avance (3-10j avant)'
        WHEN ecart_jours < 0   THEN 'Légèrement en avance (1-3j)'
        WHEN ecart_jours = 0   THEN 'À temps (jour J)'
        WHEN ecart_jours <= 3  THEN 'Léger retard (1-3j)'
        WHEN ecart_jours <= 10 THEN 'Retard modéré (3-10j)'
        ELSE                        'Retard important (>10j)'
    END
ORDER BY MIN(ecart_jours);

-- 💡 CE QU'ON CHERCHE :
--    • Note chute-t-elle quand le retard augmente ?
--    • À partir de combien de jours de retard la note < 3 ?
--    • Les commandes très en avance sont-elles mieux notées ?


-- ============================================================
-- Q4 : SATISFACTION PAR VENDEUR
-- Question business : Quels vendeurs obtiennent les
--                     meilleures/pires notes clients ?
--
-- LOGIQUE :
--   On joint reviews → orders → order_items → sellers
--   HAVING >= 30 commandes pour la fiabilité statistique
--   On combine avec le CA vendeur pour voir si les bons
--   vendeurs sont aussi les plus rentables
-- ============================================================
SELECT
    oi.seller_id,
    s.seller_state,
    s.seller_city,

    COUNT(DISTINCT r.review_id)                         AS nb_avis,
    ROUND(AVG(r.review_score)::NUMERIC, 2)             AS note_moyenne,

    -- % avis positifs (4-5 étoiles)
    ROUND(SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                         AS pct_positifs,

    -- % avis négatifs (1-2 étoiles)
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                         AS pct_negatifs,

    -- CA total du vendeur
    ROUND(SUM(oi.price)::NUMERIC, 2)                   AS ca_vendeur,

    RANK() OVER (ORDER BY AVG(r.review_score) DESC)    AS rang_satisfaction

FROM order_reviews r
JOIN orders o       ON r.order_id    = o.order_id
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN sellers s      ON oi.seller_id  = s.seller_id
WHERE o.order_status = 'delivered'
  AND r.review_score IS NOT NULL
GROUP BY oi.seller_id, s.seller_state, s.seller_city
HAVING COUNT(DISTINCT r.review_id) >= 30
ORDER BY note_moyenne DESC
LIMIT 15;

-- 💡 CE QU'ON CHERCHE :
--    • Les meilleurs vendeurs sont-ils aussi les mieux notés ?
--    • Un gros CA s'accompagne-t-il d'une bonne note ?


-- ============================================================
-- Q5 : SEGMENTATION RFM DES CLIENTS
-- Question business : Qui sont nos meilleurs clients ?
--                     Comment les segmenter pour cibler
--                     les campagnes marketing ?
--
-- LOGIQUE RFM en 3 étapes :
--
-- ÉTAPE 1 — Calculer R, F, M pour chaque client
--   R (Recency)   = nb jours depuis dernière commande
--                   → plus c'est petit, mieux c'est
--   F (Frequency) = nb total de commandes
--                   → plus c'est grand, mieux c'est
--   M (Monetary)  = CA total généré par ce client
--                   → plus c'est grand, mieux c'est
--
-- ÉTAPE 2 — Scorer chaque dimension de 1 à 3
--   NTILE(3) divise les clients en 3 groupes égaux
--   Score 3 = meilleur tiers, Score 1 = moins bon tiers
--   ⚠️ Pour Recency : score inversé (petit délai = score 3)
--
-- ÉTAPE 3 — Segmenter selon la combinaison de scores
--   Champions      : R=3, F=3, M=3
--   Fidèles        : F=3, M=3
--   À risque       : R=1, F=2-3
--   Perdus         : R=1, F=1
-- ============================================================

-- ÉTAPE 1 & 2 : Calcul et scoring RFM
WITH date_reference AS (
    -- Date de référence = dernière commande du dataset
    SELECT MAX(order_purchase_timestamp) AS date_max
    FROM orders
    WHERE order_status = 'delivered'
),
rfm_base AS (
    SELECT
        c.customer_unique_id,

        -- RECENCY : jours depuis la dernière commande
        ROUND(EXTRACT(EPOCH FROM (
            (SELECT date_max FROM date_reference)
            - MAX(o.order_purchase_timestamp)
        )) / 86400, 0)                                  AS recency_jours,

        -- FREQUENCY : nombre de commandes
        COUNT(DISTINCT o.order_id)                      AS frequency,

        -- MONETARY : CA total dépensé
        ROUND(SUM(op.payment_value)::NUMERIC, 2)       AS monetary

    FROM customers c
    JOIN orders o           ON c.customer_id  = o.customer_id
    JOIN order_payments op  ON o.order_id     = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_jours,
        frequency,
        monetary,

        -- Score Recency : inversé (petit délai = score 3 = meilleur)
        4 - NTILE(3) OVER (ORDER BY recency_jours ASC)  AS r_score,

        -- Score Frequency
        NTILE(3) OVER (ORDER BY frequency ASC)          AS f_score,

        -- Score Monetary
        NTILE(3) OVER (ORDER BY monetary ASC)           AS m_score

    FROM rfm_base
)

-- ÉTAPE 3 : Segmentation finale
SELECT
    customer_unique_id,
    recency_jours,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,

    -- Segment RFM
    CASE
        WHEN r_score = 3 AND f_score = 3 AND m_score = 3
            THEN '🏆 Champion'
        WHEN f_score = 3 AND m_score = 3
            THEN '💛 Client Fidèle'
        WHEN r_score = 3 AND f_score >= 2
            THEN '🌱 Potentiel'
        WHEN r_score = 3 AND f_score = 1
            THEN '🆕 Nouveau Client'
        WHEN r_score = 2 AND f_score >= 2
            THEN '⚠️ À Risque'
        WHEN r_score = 1 AND f_score >= 2
            THEN '🔴 Presque Perdu'
        ELSE
            '💤 Client Inactif'
    END                                                 AS segment_rfm

FROM rfm_scores
ORDER BY monetary DESC;


-- ============================================================
-- Q5-BIS : RÉSUMÉ AGRÉGÉ PAR SEGMENT RFM
-- Vue consolidée pour Power BI
-- ============================================================
WITH date_reference AS (
    SELECT MAX(order_purchase_timestamp) AS date_max
    FROM orders WHERE order_status = 'delivered'
),
rfm_base AS (
    SELECT
        c.customer_unique_id,
        ROUND(EXTRACT(EPOCH FROM (
            (SELECT date_max FROM date_reference)
            - MAX(o.order_purchase_timestamp)
        )) / 86400, 0)                                  AS recency_jours,
        COUNT(DISTINCT o.order_id)                      AS frequency,
        ROUND(SUM(op.payment_value)::NUMERIC, 2)       AS monetary
    FROM customers c
    JOIN orders o          ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id    = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT *,
        4 - NTILE(3) OVER (ORDER BY recency_jours ASC) AS r_score,
        NTILE(3) OVER (ORDER BY frequency ASC)         AS f_score,
        NTILE(3) OVER (ORDER BY monetary ASC)          AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT *,
        CASE
            WHEN r_score = 3 AND f_score = 3 AND m_score = 3 THEN '🏆 Champion'
            WHEN f_score = 3 AND m_score = 3                  THEN '💛 Client Fidèle'
            WHEN r_score = 3 AND f_score >= 2                 THEN '🌱 Potentiel'
            WHEN r_score = 3 AND f_score = 1                  THEN '🆕 Nouveau Client'
            WHEN r_score = 2 AND f_score >= 2                 THEN '⚠️ À Risque'
            WHEN r_score = 1 AND f_score >= 2                 THEN '🔴 Presque Perdu'
            ELSE                                                   '💤 Client Inactif'
        END AS segment_rfm
    FROM rfm_scores
)
SELECT
    segment_rfm,
    COUNT(*)                                            AS nb_clients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_clients,
    ROUND(AVG(monetary)::NUMERIC, 2)                   AS panier_moyen,
    ROUND(AVG(recency_jours)::NUMERIC, 0)              AS recence_moyenne_jours,
    ROUND(AVG(frequency)::NUMERIC, 2)                  AS frequence_moyenne,
    ROUND(SUM(monetary)::NUMERIC, 2)                   AS ca_total_segment
FROM rfm_segments
GROUP BY segment_rfm
ORDER BY ca_total_segment DESC;


-- ============================================================
-- RÉCAPITULATIF — Ce que ce fichier produit
-- ============================================================
/*
Q1      → 1 ligne    : KPIs satisfaction + NPS score
Q2      → ~70 lignes : Note moyenne par catégorie de produit
Q3      → 7 lignes   : Corrélation délai livraison ↔ note
Q4      → 15 lignes  : Top vendeurs par satisfaction client
Q5      → ~93k lignes: Scoring RFM individuel de chaque client
Q5-BIS  → 7 lignes   : Résumé agrégé par segment RFM

→ Ces résultats alimenteront Power BI Dashboard 3
*/
