-- ============================================================
-- PROJET : Olist E-Commerce Analytics
-- FICHIER : 05_analysis_operations.sql
-- DASHBOARD : 2 — Operations & Logistics
-- DESCRIPTION : Requêtes analytiques sur les délais de
--               livraison, statuts et performance vendeurs
-- AUTEUR : JUSTE HADASSA MALANDA NYEKELE
-- DATE : 2026
-- ============================================================
-- TABLES UTILISÉES :
--   orders      → statuts, timestamps livraison
--   order_items → lien vers vendeurs
--   sellers     → localisation vendeurs
--   customers   → localisation clients
-- ============================================================
-- RAPPEL DES TIMESTAMPS DISPONIBLES DANS orders :
--   order_purchase_timestamp       → client passe la commande
--   order_approved_at              → paiement validé
--   order_delivered_carrier_date   → remis au transporteur
--   order_delivered_customer_date  → livré au client ✅
--   order_estimated_delivery_date  → date promise au client
--
-- FORMULES CLÉS :
--   Délai réel (jours)    = delivered_customer - purchase
--   Délai estimé (jours)  = estimated_delivery - purchase
--   Délai traitement      = delivered_carrier  - approved
--   En retard ?           = delivered_customer > estimated
-- ============================================================


-- ============================================================
-- Q1 : DÉLAIS GLOBAUX — Réel vs Estimé
-- Question business : Olist tient-il ses promesses
--                     de livraison ?
--
-- LOGIQUE :
--   EXTRACT(EPOCH FROM intervalle) convertit en secondes
--   On divise par 86400 (= 60s × 60min × 24h) → jours
--   NULLIF évite la division par zéro
-- ============================================================
SELECT
    -- Délai moyen réel (achat → livraison client)
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 1)                              AS delai_reel_moyen_jours,

    -- Délai moyen estimé (achat → date promise)
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            order_estimated_delivery_date - order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 1)                              AS delai_estime_moyen_jours,

    -- Écart moyen (négatif = livré AVANT la date promise ✅)
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_estimated_delivery_date
        )) / 86400
    )::NUMERIC, 1)                              AS ecart_moyen_jours,

    -- Délai moyen traitement interne (approbation → transporteur)
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            order_delivered_carrier_date - order_approved_at
        )) / 86400
    )::NUMERIC, 1)                              AS delai_traitement_jours,

    -- Nombre de commandes analysées
    COUNT(*)                                    AS nb_commandes

FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp      IS NOT NULL;

-- 💡 CE QU'ON CHERCHE :
--    • Écart négatif = livré avant la date promise (bonne nouvelle)
--    • Écart positif = retard moyen (problème opérationnel)
--    • delai_traitement = temps que le VENDEUR met à expédier


-- ============================================================
-- Q2 : TAUX DE RETARD ET PONCTUALITÉ
-- Question business : Quelle proportion de commandes
--                     arrive en retard ?
--
-- LOGIQUE :
--   On classe chaque commande selon l'écart entre
--   date réelle et date estimée :
--   • Très en avance  : > 7 jours avant
--   • En avance       : 1-7 jours avant
--   • À temps         : le jour J (±0)
--   • Légèrement retard : 1-7 jours après
--   • Retard important  : > 7 jours après
-- ============================================================
WITH commandes_classees AS (
    SELECT
        order_id,
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_estimated_delivery_date
        )) / 86400                              AS ecart_jours
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    CASE
        WHEN ecart_jours < -7  THEN '🟢 Très en avance (>7j avant)'
        WHEN ecart_jours < 0   THEN '🟡 En avance (1-7j avant)'
        WHEN ecart_jours = 0   THEN '✅ À temps (jour J)'
        WHEN ecart_jours <= 7  THEN '🟠 Retard léger (1-7j)'
        ELSE                        '🔴 Retard important (>7j)'
    END                                         AS statut_livraison,

    COUNT(*)                                    AS nb_commandes,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
    , 2)                                        AS pourcentage

FROM commandes_classees
GROUP BY
    CASE
        WHEN ecart_jours < -7  THEN '🟢 Très en avance (>7j avant)'
        WHEN ecart_jours < 0   THEN '🟡 En avance (1-7j avant)'
        WHEN ecart_jours = 0   THEN '✅ À temps (jour J)'
        WHEN ecart_jours <= 7  THEN '🟠 Retard léger (1-7j)'
        ELSE                        '🔴 Retard important (>7j)'
    END
ORDER BY MIN(ecart_jours);

-- 💡 CE QU'ON CHERCHE :
--    • % total en retard (catégories orange + rouge)
--    • % livré en avance (Olist sur-promet-il intentionnellement ?)


-- ============================================================
-- Q3 : DÉLAIS PAR ÉTAT BRÉSILIEN
-- Question business : Certaines régions souffrent-elles
--                     de délais plus longs ?
--
-- LOGIQUE :
--   On groupe par état CLIENT (pas vendeur)
--   car c'est l'expérience client qui compte
--   On ajoute un indicateur retard par état
-- ============================================================
SELECT
    c.customer_state                            AS etat_client,

    COUNT(DISTINCT o.order_id)                  AS nb_commandes,

    -- Délai réel moyen en jours
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 1)                              AS delai_reel_moyen_jours,

    -- Délai estimé moyen en jours
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 1)                              AS delai_estime_moyen_jours,

    -- % de commandes en retard dans cet état
    ROUND(
        SUM(CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1 ELSE 0
        END) * 100.0 / COUNT(*), 2
    )                                           AS taux_retard_pct

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY delai_reel_moyen_jours DESC;

-- 💡 CE QU'ON CHERCHE :
--    • Les états du Nord (AM, RR, AP) ont probablement
--      les délais les plus longs (éloignement géographique)
--    • SP devrait avoir les délais les plus courts
--    • Corrélation entre taux_retard et délai_reel ?


-- ============================================================
-- Q4 : RÉPARTITION DES STATUTS DE COMMANDES
-- Question business : Combien de commandes sont annulées,
--                     bloquées ou non livrées ?
--
-- LOGIQUE :
--   order_status peut valoir :
--   delivered | shipped | canceled | invoiced |
--   processing | approved | created | unavailable
--
--   On ajoute une colonne description pour Power BI
-- ============================================================
SELECT
    order_status                                AS statut,

    -- Description lisible du statut
    CASE order_status
        WHEN 'delivered'    THEN '✅ Livré au client'
        WHEN 'shipped'      THEN '🚚 En transit'
        WHEN 'canceled'     THEN '❌ Annulé'
        WHEN 'invoiced'     THEN '🧾 Facturé'
        WHEN 'processing'   THEN '⚙️ En traitement'
        WHEN 'approved'     THEN '✔️ Paiement approuvé'
        WHEN 'created'      THEN '🆕 Créé'
        WHEN 'unavailable'  THEN '⛔ Indisponible'
        ELSE 'Autre'
    END                                         AS statut_description,

    COUNT(*)                                    AS nb_commandes,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
    , 2)                                        AS pourcentage

FROM orders
GROUP BY order_status
ORDER BY nb_commandes DESC;

-- 💡 CE QU'ON CHERCHE :
--    • % delivered (doit être dominant ~97%)
--    • % canceled  (indicateur de problèmes)
--    • % shipped sans delivered = commandes en cours


-- ============================================================
-- Q5 : TOP ET FLOP VENDEURS
-- Question business : Quels vendeurs livrent vite
--                     et lesquels posent problème ?
--
-- LOGIQUE :
--   Le délai vendeur = shipped_carrier - approved_at
--   C'est le temps que le VENDEUR met pour envoyer
--   le colis après validation du paiement
--   On filtre les vendeurs avec au moins 30 commandes
--   pour avoir des résultats statistiquement fiables
-- ============================================================
WITH perf_vendeurs AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        s.seller_city,
        COUNT(DISTINCT o.order_id)              AS nb_commandes,

        -- Délai moyen vendeur (approbation → transporteur)
        ROUND(AVG(
            EXTRACT(EPOCH FROM (
                o.order_delivered_carrier_date - o.order_approved_at
            )) / 86400
        )::NUMERIC, 1)                          AS delai_expedition_jours,

        -- Délai moyen livraison finale
        ROUND(AVG(
            EXTRACT(EPOCH FROM (
                o.order_delivered_customer_date - o.order_purchase_timestamp
            )) / 86400
        )::NUMERIC, 1)                          AS delai_livraison_jours,

        -- Taux de retard de ce vendeur
        ROUND(
            SUM(CASE
                WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                THEN 1 ELSE 0
            END) * 100.0 / COUNT(*), 2
        )                                       AS taux_retard_pct,

        -- CA généré par ce vendeur
        ROUND(SUM(oi.price)::NUMERIC, 2)        AS ca_vendeur

    FROM order_items oi
    JOIN orders o   ON oi.order_id  = o.order_id
    JOIN sellers s  ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_carrier_date IS NOT NULL
      AND o.order_approved_at            IS NOT NULL
    GROUP BY oi.seller_id, s.seller_state, s.seller_city
    HAVING COUNT(DISTINCT o.order_id) >= 30   -- Minimum 30 commandes
)
-- TOP 10 vendeurs (délai expédition le plus court)
SELECT
    seller_id,
    seller_state,
    seller_city,
    nb_commandes,
    delai_expedition_jours,
    delai_livraison_jours,
    taux_retard_pct,
    ca_vendeur,
    '🏆 Top vendeur'                           AS categorie
FROM perf_vendeurs
ORDER BY delai_expedition_jours ASC
LIMIT 10;

-- FLOP 10 vendeurs (délai expédition le plus long)
SELECT
    seller_id,
    seller_state,
    seller_city,
    nb_commandes,
    delai_expedition_jours,
    delai_livraison_jours,
    taux_retard_pct,
    ca_vendeur,
    '⚠️ À surveiller'                          AS categorie
FROM perf_vendeurs
ORDER BY delai_expedition_jours DESC
LIMIT 10;

-- 💡 CE QU'ON CHERCHE :
--    • Corrélation entre délai_expedition et taux_retard
--    • Les bons vendeurs compensent-ils la distance ?
--    • Les vendeurs SP ont-ils de meilleurs délais ?


-- ============================================================
-- RÉCAPITULATIF — Ce que ce fichier produit
-- ============================================================
/*
Q1 → 1 ligne    : Délais globaux réel vs estimé vs traitement
Q2 → 5 lignes   : Distribution ponctualité (retard/avance/à temps)
Q3 → 27 lignes  : Délais et taux retard par état brésilien
Q4 → 8 lignes   : Répartition complète des statuts commandes
Q5 → 10+10 lig. : Top et Flop vendeurs par délai d'expédition

→ Ces 5 résultats alimenteront Power BI Dashboard 2
*/
