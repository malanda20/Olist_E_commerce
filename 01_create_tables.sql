-- ============================================================
-- PROJET : Olist E-Commerce Analytics
-- FICHIER : 01_create_tables.sql
-- DESCRIPTION : Création de la base de données et des tables
-- AUTEUR : [Ton nom]
-- DATE : 2024
-- ============================================================
-- ORDRE D'EXÉCUTION OBLIGATOIRE :
-- Les tables sans dépendances d'abord (pas de clé étrangère),
-- ensuite les tables qui en dépendent.
--
-- 1. customers
-- 2. sellers
-- 3. product_category_translation
-- 4. products
-- 5. orders
-- 6. order_items
-- 7. order_payments
-- 8. order_reviews
-- 9. geolocation
-- ============================================================


-- ------------------------------------------------------------
-- ÉTAPE 0 : Créer la base de données (à exécuter en dehors)
-- ------------------------------------------------------------
-- CREATE DATABASE olist_ecommerce;
-- \c olist_ecommerce


-- ------------------------------------------------------------
-- ÉTAPE 1 : Suppression des tables existantes (reset propre)
-- CASCADE supprime aussi les dépendances automatiquement
-- ------------------------------------------------------------
DROP TABLE IF EXISTS order_reviews              CASCADE;
DROP TABLE IF EXISTS order_payments             CASCADE;
DROP TABLE IF EXISTS order_items                CASCADE;
DROP TABLE IF EXISTS orders                     CASCADE;
DROP TABLE IF EXISTS products                   CASCADE;
DROP TABLE IF EXISTS product_category_translation CASCADE;
DROP TABLE IF EXISTS sellers                    CASCADE;
DROP TABLE IF EXISTS customers                  CASCADE;
DROP TABLE IF EXISTS geolocation                CASCADE;


-- ------------------------------------------------------------
-- TABLE 1 : customers
-- Qui sont les acheteurs ?
-- Contient les infos de localisation des clients
-- Clé : customer_id (unique par commande)
--       customer_unique_id (unique par client réel)
-- ⚠️ Un même client peut avoir plusieurs customer_id
--    (un par commande) → customer_unique_id = vrai identifiant
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id          VARCHAR(50)  NOT NULL,  -- ID unique par commande
    customer_unique_id   VARCHAR(50),             -- ID unique par client réel
    customer_zip_code    VARCHAR(10),             -- Code postal
    customer_city        VARCHAR(100),            -- Ville
    customer_state       CHAR(2),                 -- État brésilien (ex: SP, RJ)
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);


-- ------------------------------------------------------------
-- TABLE 2 : sellers
-- Qui sont les vendeurs ?
-- Chaque vendeur est un marchand tiers sur la plateforme Olist
-- Clé : seller_id
-- ------------------------------------------------------------
CREATE TABLE sellers (
    seller_id            VARCHAR(50)  NOT NULL,  -- ID unique du vendeur
    seller_zip_code      VARCHAR(10),             -- Code postal du vendeur
    seller_city          VARCHAR(100),            -- Ville du vendeur
    seller_state         CHAR(2),                 -- État brésilien
    CONSTRAINT pk_sellers PRIMARY KEY (seller_id)
);


-- ------------------------------------------------------------
-- TABLE 3 : product_category_translation
-- Traduction des catégories Portugais → Anglais
-- Ex: "informatica_acessorios" → "computers_accessories"
-- Clé : product_category_name (en portugais)
-- ------------------------------------------------------------
CREATE TABLE product_category_translation (
    product_category_name           VARCHAR(100) NOT NULL,  -- Nom en portugais
    product_category_name_english   VARCHAR(100),           -- Nom en anglais
    CONSTRAINT pk_category_translation PRIMARY KEY (product_category_name)
);


-- ------------------------------------------------------------
-- TABLE 4 : products
-- Caractéristiques physiques des produits
-- Note : Pas de nom de produit (anonymisé par Olist)
-- Clé : product_id
-- ⚠️ Pas de FK sur product_category_name car certaines
--    catégories (ex: pc_gamer) sont absentes de la traduction
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id                  VARCHAR(50)  NOT NULL,  -- ID unique du produit
    product_category_name       VARCHAR(100),            -- Catégorie (en portugais)
    product_name_length         INT,                     -- Longueur du nom (nb caractères)
    product_description_length  INT,                     -- Longueur de la description
    product_photos_qty          INT,                     -- Nombre de photos
    product_weight_g            NUMERIC(10,2),           -- Poids en grammes
    product_length_cm           NUMERIC(10,2),           -- Longueur en cm
    product_height_cm           NUMERIC(10,2),           -- Hauteur en cm
    product_width_cm            NUMERIC(10,2),           -- Largeur en cm
    CONSTRAINT pk_products PRIMARY KEY (product_id)
);


-- ------------------------------------------------------------
-- TABLE 5 : orders  ← TABLE CENTRALE DU MODÈLE
-- Chaque ligne = une commande
-- Contient tous les statuts et timestamps du cycle de vie
-- Clé : order_id
-- Statuts possibles :
--   created | approved | invoiced | processing |
--   shipped | delivered | unavailable | canceled
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id                        VARCHAR(50)  NOT NULL,  -- ID unique de la commande
    customer_id                     VARCHAR(50),             -- FK → customers
    order_status                    VARCHAR(30),             -- Statut de la commande
    order_purchase_timestamp        TIMESTAMP,               -- Date d'achat
    order_approved_at               TIMESTAMP,               -- Date d'approbation paiement
    order_delivered_carrier_date    TIMESTAMP,               -- Date remise au transporteur
    order_delivered_customer_date   TIMESTAMP,               -- Date livraison client
    order_estimated_delivery_date   TIMESTAMP,               -- Date estimée de livraison
    CONSTRAINT pk_orders PRIMARY KEY (order_id)
);


-- ------------------------------------------------------------
-- TABLE 6 : order_items
-- Détail des articles dans chaque commande
-- Une commande peut contenir plusieurs articles (plusieurs lignes)
-- Clé composite : (order_id, order_item_id)
-- ⚠️ order_item_id = numéro de l'article dans la commande (1, 2, 3...)
-- ------------------------------------------------------------
CREATE TABLE order_items (
    order_id            VARCHAR(50)    NOT NULL,  -- FK → orders
    order_item_id       INT            NOT NULL,  -- N° de l'article dans la commande
    product_id          VARCHAR(50),               -- FK → products
    seller_id           VARCHAR(50),               -- FK → sellers
    shipping_limit_date TIMESTAMP,                 -- Date limite d'expédition vendeur
    price               NUMERIC(10,2),             -- Prix du produit (sans frais)
    freight_value       NUMERIC(10,2),             -- Frais de livraison
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id)
);


-- ------------------------------------------------------------
-- TABLE 7 : order_payments
-- Détail des paiements pour chaque commande
-- Une commande peut avoir plusieurs paiements (ex: carte + voucher)
-- Clé composite : (order_id, payment_sequential)
-- Types de paiement : credit_card | boleto | voucher | debit_card
-- ------------------------------------------------------------
CREATE TABLE order_payments (
    order_id             VARCHAR(50)   NOT NULL,  -- FK → orders
    payment_sequential   INT           NOT NULL,  -- N° du paiement (si plusieurs modes)
    payment_type         VARCHAR(30),              -- Type de paiement
    payment_installments INT,                      -- Nombre de mensualités
    payment_value        NUMERIC(10,2),            -- Montant payé
    CONSTRAINT pk_order_payments PRIMARY KEY (order_id, payment_sequential)
);


-- ------------------------------------------------------------
-- TABLE 8 : order_reviews
-- Avis laissés par les clients après livraison
-- Score de 1 (très mauvais) à 5 (excellent)
-- Clé composite : (review_id, order_id)
-- ⚠️ Certains avis n'ont pas de commentaire texte (NULL)
-- ------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id               VARCHAR(50)  NOT NULL,  -- ID unique de l'avis
    order_id                VARCHAR(50)  NOT NULL,  -- FK → orders
    review_score            INT,                     -- Note de 1 à 5 ⭐
    review_comment_title    VARCHAR(255),            -- Titre du commentaire
    review_comment_message  TEXT,                    -- Corps du commentaire
    review_creation_date    TIMESTAMP,               -- Date de création de l'avis
    review_answer_timestamp TIMESTAMP,               -- Date de réponse
    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id, order_id),
    CONSTRAINT chk_review_score CHECK (review_score BETWEEN 1 AND 5)
);


-- ------------------------------------------------------------
-- TABLE 9 : geolocation
-- Coordonnées GPS par code postal brésilien
-- Utilisé pour les cartes et analyses géographiques
-- ⚠️ Pas de clé primaire : un même zip_code peut avoir
--    plusieurs entrées GPS (moyenne de plusieurs points)
-- ------------------------------------------------------------
CREATE TABLE geolocation (
    geolocation_zip_code VARCHAR(10),    -- Code postal
    geolocation_lat      NUMERIC(9,6),   -- Latitude
    geolocation_lng      NUMERIC(9,6),   -- Longitude
    geolocation_city     VARCHAR(100),   -- Ville
    geolocation_state    CHAR(2)         -- État brésilien
);


-- ------------------------------------------------------------
-- VÉRIFICATION : Lister les tables créées
-- ------------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
