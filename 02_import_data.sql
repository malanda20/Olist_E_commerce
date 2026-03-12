-- ============================================================
-- PROJET : Olist E-Commerce Analytics
-- FICHIER : 02_import_data.sql
-- DESCRIPTION : Import des fichiers CSV dans PostgreSQL
-- AUTEUR : JUSTE HADASSA MALANDA NYEKELE
-- DATE : 2026
-- ============================================================
-- PRÉREQUIS :
--   - Avoir exécuté 01_create_tables.sql
--   - Être connecté à la base olist_ecommerce
--   - Utiliser psql (pas pgAdmin) pour les commandes \COPY
--
-- ⚠️ IMPORTANT :
--   - Remplace [TON_CHEMIN] par le chemin réel de tes fichiers
--   - Exemple Windows : C:\Users\EliteBook\Downloads\archive
--   - Exemple Mac/Linux : /home/user/downloads/archive
--
-- ORDRE D'IMPORT OBLIGATOIRE (respecter les dépendances) :
--   1. customers
--   2. sellers
--   3. product_category_translation
--   4. products
--   5. orders
--   6. order_items
--   7. order_payments
--   8. order_reviews  ← encodage spécial UTF8
--   9. geolocation
-- ============================================================


-- ------------------------------------------------------------
-- ÉTAPE 1 : Import customers
-- Fichier : olist_customers_dataset.csv
-- Lignes attendues : ~99 441
-- ------------------------------------------------------------
\COPY customers FROM '[TON_CHEMIN]\olist_customers_dataset.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 2 : Import sellers
-- Fichier : olist_sellers_dataset.csv
-- Lignes attendues : ~3 095
-- ------------------------------------------------------------
\COPY sellers FROM '[TON_CHEMIN]\olist_sellers_dataset.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 3 : Import product_category_translation
-- Fichier : product_category_name_translation.csv
-- Lignes attendues : ~71
-- ------------------------------------------------------------
\COPY product_category_translation FROM '[TON_CHEMIN]\product_category_name_translation.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 4 : Import products
-- Fichier : olist_products_dataset.csv
-- Lignes attendues : ~32 951
-- ⚠️ Certaines catégories (ex: pc_gamer) n'ont pas de
--    traduction → c'est normal, pas d'erreur attendue
-- ------------------------------------------------------------
\COPY products FROM '[TON_CHEMIN]\olist_products_dataset.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 5 : Import orders
-- Fichier : olist_orders_dataset.csv
-- Lignes attendues : ~99 441
-- ------------------------------------------------------------
\COPY orders FROM '[TON_CHEMIN]\olist_orders_dataset.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 6 : Import order_items
-- Fichier : olist_order_items_dataset.csv
-- Lignes attendues : ~112 650
-- ------------------------------------------------------------
\COPY order_items FROM '[TON_CHEMIN]\olist_order_items_dataset.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 7 : Import order_payments
-- Fichier : olist_order_payments_dataset.csv
-- Lignes attendues : ~103 886
-- ------------------------------------------------------------
\COPY order_payments FROM '[TON_CHEMIN]\olist_order_payments_dataset.csv' DELIMITER ',' CSV HEADER;


-- ------------------------------------------------------------
-- ÉTAPE 8 : Import order_reviews
-- Fichier : olist_order_reviews_clean2.csv  ← version nettoyée
-- Lignes attendues : ~99 224
--
-- ⚠️ ENCODAGE SPÉCIAL :
--    Le fichier original contient des bytes invalides (0x8f)
--    Solution appliquée : nettoyage via Python (latin-1 → utf-8)
--    Script de nettoyage utilisé :
--
--    with open('olist_order_reviews_dataset.csv', 'rb') as f:
--        raw = f.read()
--    text = raw.decode('latin-1')
--    with open('olist_order_reviews_clean2.csv', 'w',
--              encoding='utf-8', newline='') as f:
--        f.write(text)
-- ------------------------------------------------------------
\COPY order_reviews FROM '[TON_CHEMIN]\olist_order_reviews_clean2.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8';


-- ------------------------------------------------------------
-- ÉTAPE 9 : Import geolocation
-- Fichier : olist_geolocation_dataset.csv
-- Lignes attendues : ~1 000 163
-- ℹ️ C'est le fichier le plus volumineux, import plus long
-- ------------------------------------------------------------
\COPY geolocation FROM '[TON_CHEMIN]\olist_geolocation_dataset.csv' DELIMITER ',' CSV HEADER;


-- ============================================================
-- VÉRIFICATION FINALE
-- Résultats attendus :
--   customers      →    99 441
--   sellers        →     3 095
--   products       →    32 951
--   orders         →    99 441
--   order_items    →   112 650
--   order_payments →   103 886
--   order_reviews  →    99 224
--   geolocation    → 1 000 163
-- ============================================================
SELECT 'customers'        AS table_name, COUNT(*) AS nb_lignes FROM customers
UNION ALL
SELECT 'sellers',                        COUNT(*) FROM sellers
UNION ALL
SELECT 'products',                       COUNT(*) FROM products
UNION ALL
SELECT 'orders',                         COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',                    COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments',                 COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews',                  COUNT(*) FROM order_reviews
UNION ALL
SELECT 'geolocation',                    COUNT(*) FROM geolocation
ORDER BY table_name;
