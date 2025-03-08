-- Создание объекта postgis
CREATE EXTENSION IF NOT EXISTS postgis;

-- Подключаем расширение для работы с UUID, если оно ещё не установлено
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Перечисления (ENUM types) для улучшения читаемости и валидации
CREATE TYPE object_type AS ENUM ('земельный участок', 'здание', 'помещение', 'сооружение');
CREATE TYPE legal_status AS ENUM ('в собственности', 'в аренде', 'в залоге', 'постоянное пользование');
CREATE TYPE land_category AS ENUM ('сельхоз', 'промышленная', 'лесной фонд', 'жилое');
CREATE TYPE building_material AS ENUM ('кирпич', 'бетон', 'дерево', 'металл');
CREATE TYPE room_type AS ENUM ('офисное', 'жилое', 'складское');
CREATE TYPE condit AS ENUM ('отличное', 'удовлетворительное', 'неудовлетворительное', 'аварийное');
CREATE TYPE income_type AS ENUM ('аренда', 'продажа', 'прочее');
CREATE TYPE expense_type AS ENUM ('обслуживание', 'ремонт', 'коммунальные услуги', 'прочее');
CREATE TYPE document_type AS ENUM ('договор', 'счет', 'отчет', 'прочее');

-- Модуль "Общие Справочники"
CREATE SCHEMA IF NOT EXISTS reference;


-- Таблица для хранения данных контактных лиц
CREATE TABLE reference.representatives (
    id SERIAL PRIMARY KEY,                          -- Уникальный автоинкрементный идентификатор
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),    -- Уникальный идентификатор для интеграции с внешними системами
    last_name VARCHAR(50) NOT NULL,                 -- Фамилия контактного лица (максимум 50 символов)
    first_name VARCHAR(50) NOT NULL,                -- Имя контактного лица (максимум 50 символов)
    middle_name VARCHAR(50),                        -- Отчество контактного лица (максимум 50 символов), необязательное поле
    phone VARCHAR(20),                              -- Телефонный номер контактного лица (максимум 20 символов, включая код страны), необязательное поле
    email VARCHAR(100),                             -- Электронная почта контактного лица (максимум 100 символов), необязательное поле
    other_contacts TEXT,                            -- Дополнительные контактные данные (например, соцсети, мессенджеры), необязательное поле
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')  -- Проверка формата email
);

-- Индекс на фамилию для ускорения поиска
CREATE INDEX idx_last_name ON reference.representatives(last_name);

-- Индекс на email для ускорения поиска
CREATE INDEX idx_email ON reference.representatives(email);

-- Таблица для хранения данных контрагентов
CREATE TABLE reference.legal_entities (
    id SERIAL PRIMARY KEY,                          -- Уникальный автоинкрементный идентификатор
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),    -- Уникальный идентификатор для внешних интеграций
    legal_form VARCHAR(20) NOT NULL,                -- Юридическая форма (например, ООО, ОАО, ИП), максимум 20 символов
    name VARCHAR(255) NOT NULL,                     -- Полное наименование юридического лица, максимум 255 символов
    representative_id INTEGER REFERENCES reference.representatives(id),  -- Ссылка на представителя
    basis VARCHAR(100),                             -- Основание (например, устав, доверенность), максимум 100 символов
    additional_basis_info TEXT,                     -- Дополнительная информация об основании
    inn CHAR(12) NOT NULL,                          -- ИНН фиксированной длины (10 или 12 цифр), обязательное поле
    requisites_id INTEGER REFERENCES legal_accounting.requisites(id),  -- Ссылка на реквизиты контрагента
    comments TEXT,                                  -- Дополнительные комментарии
    CONSTRAINT inn_format CHECK (inn ~ '^\d{10}$' OR inn ~ '^\d{12}$')  -- Проверка формата ИНН
);

-- Индекс на поле name для ускорения поиска по наименованию контрагента
CREATE INDEX idx_legal_entity_name ON reference.legal_entities(name);

-- Индекс на поле inn для ускорения поиска по ИНН
CREATE INDEX idx_legal_entity_inn ON reference.legal_entities(inn);


-- Таблица для хранения адресов
CREATE TABLE reference.addresses (
    id SERIAL PRIMARY KEY,                           -- Уникальный автоинкрементный идентификатор
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),     -- Уникальный идентификатор для внешней интеграции
    country VARCHAR(100) NOT NULL,                   -- Страна, обязательное поле, максимум 100 символов
    region VARCHAR(100),                             -- Регион или область, максимум 100 символов
    city VARCHAR(100),                               -- Город, максимум 100 символов
    street VARCHAR(255),                             -- Улица, максимум 255 символов
    house VARCHAR(50),                               -- Номер дома, максимум 50 символов
    apartment VARCHAR(50),                           -- Номер квартиры, максимум 50 символов
    postal_code CHAR(6),                             -- Почтовый индекс фиксированной длины (6 цифр)
    CONSTRAINT postal_code_format CHECK (postal_code ~ '^\d{6}$' OR postal_code IS NULL)  -- Проверка формата почтового индекса (6 цифр)
);

-- Индекс на поле city для ускорения поиска по городу
CREATE INDEX idx_address_city ON reference.addresses(city);

-- Индекс на поле country для ускорения поиска по стране
CREATE INDEX idx_address_country ON reference.addresses(country);

-- Индекс на поле postal_code для ускорения поиска по почтовому индексу
CREATE INDEX idx_address_postal_code ON reference.addresses(postal_code);


-- Таблица для хранения контрактов
CREATE TABLE reference.contracts (
    id SERIAL PRIMARY KEY,                                    -- Уникальный автоинкрементный идентификатор
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),              -- Уникальный идентификатор для внешней интеграции
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости, обязательное поле
    contract_type VARCHAR(50) NOT NULL,                      -- Тип контракта (например, аренда, купля-продажа), максимум 50 символов, обязательное поле
    contract_number VARCHAR(50) NOT NULL,                    -- Номер контракта, максимум 50 символов, обязательное поле
    contract_date DATE NOT NULL,                             -- Дата заключения контракта, обязательное поле
    validity_period DATE,                                     -- Срок действия контракта, необязательное поле
    parties TEXT NOT NULL,                                   -- Стороны контракта (описание сторон), обязательное поле
    document_scan TEXT,                                      -- Скан документа контракта (путь или Base64), необязательное поле
    additional_info TEXT,                                    -- Дополнительная информация, необязательное поле
    comments TEXT,                                           -- Комментарии, необязательное поле
    CONSTRAINT validity_check CHECK (validity_period >= contract_date OR validity_period IS NULL)  -- Проверка, чтобы срок действия был не ранее даты заключения
);

-- Индекс на поле contract_number для ускорения поиска по номеру контракта
CREATE INDEX idx_contract_number ON reference.contracts(contract_number);

-- Индекс на поле contract_date для ускорения поиска по дате контракта
CREATE INDEX idx_contract_date ON reference.contracts(contract_date);


-- Таблица для хранения актов
CREATE TABLE reference.acts (
    id SERIAL PRIMARY KEY,                                          -- Уникальный автоинкрементный идентификатор
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                    -- Уникальный идентификатор для внешней интеграции
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,                        -- Связь с объектом недвижимости, обязательное поле, каскадное удаление
    contract_id INTEGER NOT NULL REFERENCES reference.contracts(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,                        -- Связь с контрактом, обязательное поле, каскадное удаление
    act_number VARCHAR(50) NOT NULL,                                -- Номер акта, максимум 50 символов, обязательное поле
    act_date DATE NOT NULL,                                         -- Дата акта, обязательное поле
    performed_by INTEGER REFERENCES reference.legal_entities(id) 
        ON DELETE SET NULL ON UPDATE CASCADE,                       -- Связь с контрагентом, который выполнил работу или услугу, NULL при удалении
    total_cost DECIMAL(18, 2),                                      -- Общая стоимость с двумя знаками после запятой, необязательное поле
    document_scan TEXT,                                             -- Скан документа акта (путь или Base64), необязательное поле
    comments TEXT,                                                  -- Дополнительные комментарии, необязательное поле
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                 -- Дата создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                 -- Дата последнего обновления записи
    CONSTRAINT cost_positive CHECK (total_cost >= 0 OR total_cost IS NULL) -- Проверка, что общая стоимость не может быть отрицательной
);

-- Индекс на поле act_number для ускорения поиска по номеру акта
CREATE INDEX idx_act_number ON reference.acts(act_number);

-- Индекс на поле act_date для ускорения поиска по дате акта
CREATE INDEX idx_act_date ON reference.acts(act_date);



-- Модуль "Объекты Недвижимости"
CREATE SCHEMA IF NOT EXISTS real_estate;

-- Таблица для хранения базовых данных об объектах недвижимости
CREATE TABLE real_estate.objects (
    id SERIAL PRIMARY KEY,                                          -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                    -- UUID для обеспечения уникальности записи и внешней интеграции
    name VARCHAR(255) NOT NULL,                                      -- Название объекта недвижимости, ограничение длины до 255 символов
    parent_id INTEGER REFERENCES real_estate.objects(id),            -- Внешний ключ на родительский объект, если объект является частью другого (например, здание на участке)
    object_type object_type NOT NULL,                                -- Тип объекта недвижимости (например, жилой, коммерческий), предполагается использование перечисления
    address_id INTEGER REFERENCES reference.addresses(id),          -- Внешний ключ на таблицу адресов, связывающий объект с его физическим местоположением
    total_area DECIMAL(12, 2),                                       -- Общая площадь объекта недвижимости (до 12 цифр с двумя знаками после запятой)
    unit_of_measurement VARCHAR(50),                                 -- Единица измерения площади (например, м², км²), ограничение до 50 символов
    plan_location VARCHAR(255),                                      -- Местоположение объекта на плане (например, номер участка, номер этажа), ограничение до 255 символов
    description TEXT,                                                -- Описание объекта недвижимости, необязательное поле для дополнительных данных
    coordinates geometry(Point, 4326),                               -- Географические координаты объекта с использованием PostGIS для работы с точками
    bounding_polygon geometry(Polygon, 4326),                        -- Геометрия для описания границ объекта с использованием полигона (например, для участка земли)
    envelope geometry(Polygon, 4326),                                  -- Описание ограничивающего прямоугольника (envelope), который может быть полезен для быстрого поиска объектов в пределах определенной зоны
    area_polygon geometry(Polygon, 4326),                            -- Геометрия для представления площади в виде полигона, может быть использована для площади участка или объекта
    comments TEXT                                                    -- Дополнительные комментарии, необязательное поле для дополнительной информации об объекте
);

-- Индекс на поле name для ускорения поиска по названию объекта
CREATE INDEX idx_object_name ON real_estate.objects(name);

-- Индекс на поле coordinates для ускорения пространственных запросов по точкам
CREATE INDEX idx_object_coordinates ON real_estate.objects USING GIST (coordinates);

-- Индекс на поле bounding_polygon для ускорения пространственных запросов по полигонам
CREATE INDEX idx_object_bounding_polygon ON real_estate.objects USING GIST (bounding_polygon);

-- Индекс на поле area_polygon для ускорения пространственных запросов по полигонам
CREATE INDEX idx_object_area_polygon ON real_estate.objects USING GIST (area_polygon);

-- Таблица для хранения характеристик земельных участков

CREATE TABLE real_estate.land_characteristics (
    id SERIAL PRIMARY KEY,                                               -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                         -- UUID для обеспечения уникальности записи и внешней интеграции
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),        -- Внешний ключ на объект недвижимости (связь с таблицей объектов недвижимости)
    land_area DECIMAL(12, 2),                                             -- Площадь земельного участка (до 12 цифр с двумя знаками после запятой)
    land_category land_category,                                          -- Категория земель (например, сельхозземли, промзона, жилые земли) предполагается использование перечисления (enum)
    allowed_use VARCHAR(255),                                             -- Разрешенное использование земли (например, для строительства, сельского хозяйства), ограничение до 255 символов
    zoning VARCHAR(255),                                                 -- Зонирование участка (например, зона жилой застройки, зона рекреации), ограничение до 255 символов
    comments TEXT                                                         -- Дополнительные комментарии для характеристики земельного участка
);

-- Индекс на поле object_id для ускорения запросов по объектам недвижимости
CREATE INDEX idx_land_characteristics_object_id ON real_estate.land_characteristics(object_id);

-- Индекс на поле land_category для ускорения поиска по категории земель
CREATE INDEX idx_land_category ON real_estate.land_characteristics(land_category);

-- Индекс на поле land_area для ускорения запросов, связанных с площадью земельных участков
CREATE INDEX idx_land_area ON real_estate.land_characteristics(land_area);

-- Индекс на поле allowed_use для ускорения запросов по разрешенному использованию земли
CREATE INDEX idx_allowed_use ON real_estate.land_characteristics(allowed_use);

-- Индекс на поле zoning для ускорения запросов по зонированию участков
CREATE INDEX idx_zoning ON real_estate.land_characteristics(zoning);

-- Таблица для хранения характеристик зданий
CREATE TABLE real_estate.building_characteristics (
    id SERIAL PRIMARY KEY,                                                 -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                           -- UUID для уникальности записи и внешней интеграции
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),          -- Внешний ключ на объект недвижимости (связь с таблицей объектов недвижимости)
    year_of_construction INTEGER CHECK (year_of_construction > 0),         -- Год постройки здания, проверка, чтобы год был положительным числом
    building_area DECIMAL(12, 2),                                          -- Площадь здания, точность до 12 знаков, 2 знака после запятой
    number_of_floors INTEGER CHECK (number_of_floors > 0),                 -- Количество этажей, проверка на положительное значение
    construction_material building_material,                                -- Материал строительства (предполагается использование перечисления для типов материалов)
    commissioning_date DATE,                                               -- Дата ввода в эксплуатацию здания
    comments TEXT                                                           -- Дополнительные комментарии по характеристикам здания
);

-- Индекс на поле object_id для ускорения запросов по объектам недвижимости
CREATE INDEX idx_building_characteristics_object_id ON real_estate.building_characteristics(object_id);

-- Индекс на поле year_of_construction для ускорения запросов, связанных с годом постройки
CREATE INDEX idx_year_of_construction ON real_estate.building_characteristics(year_of_construction);

-- Индекс на поле building_area для ускорения запросов, связанных с площадью зданий
CREATE INDEX idx_building_area ON real_estate.building_characteristics(building_area);

-- Индекс на поле number_of_floors для ускорения запросов по количеству этажей
CREATE INDEX idx_number_of_floors ON real_estate.building_characteristics(number_of_floors);

-- Индекс на поле construction_material для ускорения поиска по материалам строительства
CREATE INDEX idx_construction_material ON real_estate.building_characteristics(construction_material);

-- Таблица для хранения характеристик помещений
CREATE TABLE real_estate.room_characteristics (
    id SERIAL PRIMARY KEY,                                                  -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                            -- UUID для уникальности записи и внешней интеграции
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),           -- Внешний ключ на объект недвижимости (связь с таблицей объектов недвижимости)
    parent_building_id INTEGER REFERENCES real_estate.objects(id),          -- Внешний ключ на родительский объект (например, здание), если помещение является частью большого объекта
    room_area DECIMAL(12, 2) CHECK (room_area > 0),                          -- Площадь помещения, с проверкой на положительное значение
    floor INTEGER CHECK (floor > 0),                                         -- Этаж, на котором находится помещение, с проверкой на положительное значение
    room_type room_type NOT NULL,                                            -- Тип помещения (например, офис, квартира, склад и т.д.)
    comments TEXT                                                            -- Дополнительные комментарии по характеристикам помещения
);

-- Индекс на поле object_id для ускорения запросов по объектам недвижимости
CREATE INDEX idx_room_characteristics_object_id ON real_estate.room_characteristics(object_id);

-- Индекс на поле parent_building_id для ускорения поиска по родительским объектам (например, по зданию)
CREATE INDEX idx_parent_building_id ON real_estate.room_characteristics(parent_building_id);

-- Индекс на поле floor для ускорения запросов по этажу помещения
CREATE INDEX idx_floor ON real_estate.room_characteristics(floor);

-- Индекс на поле room_type для ускорения поиска по типу помещения
CREATE INDEX idx_room_type ON real_estate.room_characteristics(room_type);


-- Таблица для хранения дополнительных характеристик
CREATE TABLE real_estate.additional_characteristics (
    id SERIAL PRIMARY KEY,                                                    -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                              -- UUID для уникальности записи и внешней интеграции
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),             -- Внешний ключ на объект недвижимости
    market_value DECIMAL(15, 2) CHECK (market_value >= 0),                      -- Рыночная стоимость объекта, с проверкой на неотрицательное значение
    cadastral_value DECIMAL(15, 2) CHECK (cadastral_value >= 0),                -- Кадастровая стоимость объекта, с проверкой на неотрицательное значение
    physical_condition condit NOT NULL,                                        -- Физическое состояние объекта (предположительно это тип или перечисление)
    communications JSON,                                                       -- Коммуникации (связи с коммунальными услугами, инвентаризацией и т.д.)
    last_repair_date DATE,                                                     -- Дата последнего ремонта
    mortgage_info TEXT,                                                        -- Информация о наличии ипотеки
    additional_info TEXT,                                                      -- Дополнительная информация
    comments TEXT                                                              -- Дополнительные комментарии
);

-- Индекс на поле object_id для ускорения запросов по объектам недвижимости
CREATE INDEX idx_additional_characteristics_object_id ON real_estate.additional_characteristics(object_id);

-- Индекс на поле market_value для ускорения запросов, связанных с рыночной стоимостью
CREATE INDEX idx_market_value ON real_estate.additional_characteristics(market_value);

-- Индекс на поле cadastral_value для ускорения запросов по кадастровой стоимости
CREATE INDEX idx_cadastral_value ON real_estate.additional_characteristics(cadastral_value);

-- Индекс на поле last_repair_date для ускорения запросов по дате последнего ремонта
CREATE INDEX idx_last_repair_date ON real_estate.additional_characteristics(last_repair_date);

-- Индекс на поле physical_condition для ускорения запросов по физическому состоянию объекта
CREATE INDEX idx_physical_condition ON real_estate.additional_characteristics(physical_condition);

-- Модуль "УЧЕТ и ПРАВА"
CREATE SCHEMA IF NOT EXISTS legal_accounting;

-- Таблица для хранения реквизитов
CREATE TABLE legal_accounting.requisites (
    id SERIAL PRIMARY KEY,                                                   -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                             -- UUID для уникальности записи и внешней интеграции
    requisites_data JSONB NOT NULL,                                           -- Данные реквизитов в формате JSONB (с возможностью использования индексов)
    additional_info TEXT,                                                     -- Дополнительная информация
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                           -- Дата и время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                            -- Дата и время последнего обновления записи
);

-- Индекс на поле requisites_data для улучшения производительности запросов с фильтрацией по данным реквизитов
CREATE INDEX idx_requisites_data ON legal_accounting.requisites USING GIN (requisites_data);

-- Индекс на поле created_at для ускорения запросов по дате создания
CREATE INDEX idx_created_at ON legal_accounting.requisites(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления
CREATE INDEX idx_updated_at ON legal_accounting.requisites(updated_at);

-- Таблица для хранения характеристик учета
CREATE TABLE legal_accounting.asset_management (
    id SERIAL PRIMARY KEY,                                                  -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                            -- UUID для внешней интеграции и обеспечения уникальности
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),           -- Внешний ключ на объект недвижимости (связь с таблицей real_estate.objects)
    cadastral_number VARCHAR(50),                                           -- Кадастровый номер объекта недвижимости (с ограничением длины на 50 символов)
    rnfi_number VARCHAR(50),                                                -- Номер РНФИ (с ограничением длины на 50 символов)
    department VARCHAR(100),                                                -- Отдел, ответственный за актив (с ограничением длины на 100 символов)
    main_asset VARCHAR(255),                                                -- Основной актив (например, тип актива или описание) (с ограничением длины на 255 символов)
    comments TEXT,                                                          -- Дополнительные комментарии (неограниченная длина текста)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                          -- Дата и время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                           -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов с фильтрацией по объектам недвижимости
CREATE INDEX idx_asset_object_id ON legal_accounting.asset_management(object_id);

-- Индекс на поле cadastral_number для ускорения запросов по кадастровому номеру
CREATE INDEX idx_cadastral_number ON legal_accounting.asset_management(cadastral_number);

-- Индекс на поле rnfi_number для ускорения запросов по номеру РНФИ
CREATE INDEX idx_rnfi_number ON legal_accounting.asset_management(rnfi_number);

-- Индекс на поле department для ускорения запросов по отделу
CREATE INDEX idx_department ON legal_accounting.asset_management(department);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_created_at ON legal_accounting.asset_management(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_updated_at ON legal_accounting.asset_management(updated_at);


-- Таблица для хранения характеристик права
CREATE TABLE legal_accounting.property_rights (
    id SERIAL PRIMARY KEY,                                                   -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                             -- UUID для внешней интеграции и обеспечения уникальности
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),            -- Внешний ключ на объект недвижимости (связь с таблицей real_estate.objects)
    right_type legal_status NOT NULL,                                         -- Тип права (например, собственность, аренда, ипотека и т. д.) с типом данных legal_status
    egrn_number VARCHAR(50),                                                  -- Номер записи в Едином государственном реестре недвижимости (ЕГРН), ограничение на 50 символов
    egrn_date DATE,                                                          -- Дата регистрации в ЕГРН
    certificate_series VARCHAR(10),                                           -- Серия свидетельства о праве собственности (ограничение на 10 символов)
    certificate_number VARCHAR(20),                                          -- Номер свидетельства о праве собственности (ограничение на 20 символов)
    certificate_issue_date DATE,                                             -- Дата выдачи свидетельства
    comments TEXT,                                                           -- Дополнительные комментарии (неограниченная длина текста)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                           -- Дата и время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                            -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов с фильтрацией по объектам недвижимости
CREATE INDEX idx_property_rights_object_id ON legal_accounting.property_rights(object_id);

-- Индекс на поле egrn_number для ускорения запросов по номеру записи в ЕГРН
CREATE INDEX idx_egrn_number ON legal_accounting.property_rights(egrn_number);

-- Индекс на поле certificate_number для ускорения запросов по номеру свидетельства
CREATE INDEX idx_certificate_number ON legal_accounting.property_rights(certificate_number);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_property_rights_created_at ON legal_accounting.property_rights(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_property_rights_updated_at ON legal_accounting.property_rights(updated_at);

-- Таблица для хранения справочника собственников
CREATE TABLE legal_accounting.owners (
    id SERIAL PRIMARY KEY,                                                   -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                             -- UUID для внешней интеграции и обеспечения уникальности
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),            -- Внешний ключ на объект недвижимости (связь с таблицей real_estate.objects)
    owner_name VARCHAR(255) NOT NULL,                                          -- Имя владельца объекта недвижимости, ограничено 255 символами
    agent_name VARCHAR(255),                                                   -- Имя агента, если он действует от имени владельца, ограничено 255 символами
    agent_contract VARCHAR(255),                                              -- Номер или данные контракта агента, ограничено 255 символами
    requisites_id INTEGER REFERENCES legal_accounting.requisites(id),         -- Внешний ключ на таблицу реквизитов, может быть NULL, если реквизиты отсутствуют
    comments TEXT,                                                           -- Дополнительные комментарии, неограниченная длина текста
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                           -- Дата и время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                            -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов с фильтрацией по объектам недвижимости
CREATE INDEX idx_owners_object_id ON legal_accounting.owners(object_id);

-- Индекс на поле owner_name для ускорения поиска владельцев по имени
CREATE INDEX idx_owners_owner_name ON legal_accounting.owners(owner_name);

-- Индекс на поле agent_name для ускорения поиска владельцев по имени агента
CREATE INDEX idx_owners_agent_name ON legal_accounting.owners(agent_name);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_owners_created_at ON legal_accounting.owners(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_owners_updated_at ON legal_accounting.owners(updated_at);

-- Таблица для хранения данных об аренде
CREATE TABLE legal_accounting.rental (
    id SERIAL PRIMARY KEY,                                                     -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                               -- UUID для внешней интеграции и обеспечения уникальности
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),              -- Внешний ключ на объект недвижимости (связь с таблицей real_estate.objects)
    rental_status VARCHAR(50),                                                 -- Статус аренды (например, активен, завершен), ограничено 50 символами
    rental_start_date DATE,                                                    -- Дата начала аренды
    rental_end_date DATE,                                                      -- Дата окончания аренды
    renter_name VARCHAR(255),                                                  -- Имя арендатора, ограничено 255 символами
    rental_contract VARCHAR(255),                                              -- Номер контракта аренды, ограничено 255 символами
    rental_price_category VARCHAR(50),                                         -- Категория аренды (например, коммерческая, жилая), ограничено 50 символами
    comments TEXT,                                                             -- Дополнительные комментарии, неограниченная длина текста
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                             -- Дата и время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                              -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов с фильтрацией по объектам недвижимости
CREATE INDEX idx_rental_object_id ON legal_accounting.rental(object_id);

-- Индекс на поле rental_status для ускорения запросов по статусу аренды
CREATE INDEX idx_rental_status ON legal_accounting.rental(rental_status);

-- Индекс на поле rental_start_date для ускорения запросов по дате начала аренды
CREATE INDEX idx_rental_start_date ON legal_accounting.rental(rental_start_date);

-- Индекс на поле rental_end_date для ускорения запросов по дате окончания аренды
CREATE INDEX idx_rental_end_date ON legal_accounting.rental(rental_end_date);

-- Индекс на поле renter_name для ускорения поиска арендаторов по имени
CREATE INDEX idx_rental_renter_name ON legal_accounting.rental(renter_name);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_rental_created_at ON legal_accounting.rental(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_rental_updated_at ON legal_accounting.rental(updated_at);

-- Модуль "ТОиР"
CREATE SCHEMA IF NOT EXISTS maintenance;

-- Таблица для хранения данных об оборудовании
CREATE TABLE maintenance.equipment (
    id SERIAL PRIMARY KEY,                                                     -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                               -- UUID для внешней интеграции и обеспечения уникальности
    object_id INTEGER REFERENCES real_estate.objects(id),                      -- Внешний ключ на объект недвижимости, ссылается на таблицу real_estate.objects
    contract_id INTEGER REFERENCES reference.contracts(id),                    -- Внешний ключ на контракт, ссылается на таблицу reference.contracts
    name VARCHAR(255) NOT NULL,                                                 -- Название оборудования, ограничено 255 символами
    type VARCHAR(100),                                                         -- Тип оборудования (например, кондиционер, лифт и т.п.), ограничено 100 символами
    manufacturer VARCHAR(100),                                                 -- Производитель оборудования, ограничено 100 символами
    model VARCHAR(100),                                                       -- Модель оборудования, ограничено 100 символами
    serial_number VARCHAR(100),                                               -- Серийный номер оборудования, ограничено 100 символами
    installation_date DATE,                                                    -- Дата установки оборудования
    maintenance_schedule TEXT,                                                 -- График обслуживания (может быть в виде текста, можно использовать JSON для более сложных структур)
    comments TEXT,                                                             -- Дополнительные комментарии, неограниченная длина текста
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                             -- Дата и время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                              -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов по объектам недвижимости
CREATE INDEX idx_equipment_object_id ON maintenance.equipment(object_id);

-- Индекс на поле contract_id для улучшения производительности запросов по контрактам
CREATE INDEX idx_equipment_contract_id ON maintenance.equipment(contract_id);

-- Индекс на поле name для ускорения поиска оборудования по названию
CREATE INDEX idx_equipment_name ON maintenance.equipment(name);

-- Индекс на поле installation_date для улучшения запросов по дате установки оборудования
CREATE INDEX idx_equipment_installation_date ON maintenance.equipment(installation_date);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_equipment_created_at ON maintenance.equipment(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_equipment_updated_at ON maintenance.equipment(updated_at);

-- Таблица для хранения данных о выполненных работах
CREATE TABLE maintenance.maintenance_works (
    id SERIAL PRIMARY KEY,                                                     -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                               -- UUID для внешней интеграции и обеспечения уникальности записи
    object_id INTEGER REFERENCES real_estate.objects(id),                      -- Внешний ключ на объект недвижимости, ссылается на таблицу real_estate.objects
    equipment_id INTEGER REFERENCES maintenance.equipment(id),                  -- Внешний ключ на оборудование, ссылается на таблицу maintenance.equipment
    contract_id INTEGER REFERENCES reference.contracts(id),                    -- Внешний ключ на контракт, ссылается на таблицу reference.contracts
    act_id INTEGER REFERENCES reference.acts(id),                              -- Внешний ключ на акт, ссылается на таблицу reference.acts
    performer_id INTEGER REFERENCES reference.legal_entities(id),              -- Внешний ключ на исполнителя, ссылается на таблицу reference.legal_entities
    work_type VARCHAR(255) NOT NULL,                                            -- Тип выполняемой работы, ограничено 255 символами
    work_date DATE NOT NULL,                                                    -- Дата выполнения работы
    cost DECIMAL(10, 2),                                                        -- Стоимость работы, с точностью до 2 знаков после запятой
    comments TEXT,                                                             -- Дополнительные комментарии, неограниченная длина текста
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                             -- Дата и время создания записи, по умолчанию текущая дата и время
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                              -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов по объектам недвижимости
CREATE INDEX idx_maintenance_works_object_id ON maintenance.maintenance_works(object_id);

-- Индекс на поле equipment_id для улучшения производительности запросов по оборудованию
CREATE INDEX idx_maintenance_works_equipment_id ON maintenance.maintenance_works(equipment_id);

-- Индекс на поле contract_id для улучшения производительности запросов по контрактам
CREATE INDEX idx_maintenance_works_contract_id ON maintenance.maintenance_works(contract_id);

-- Индекс на поле act_id для улучшения производительности запросов по актам
CREATE INDEX idx_maintenance_works_act_id ON maintenance.maintenance_works(act_id);

-- Индекс на поле performer_id для улучшения производительности запросов по исполнителям
CREATE INDEX idx_maintenance_works_performer_id ON maintenance.maintenance_works(performer_id);

-- Индекс на поле work_date для ускорения запросов по дате работы
CREATE INDEX idx_maintenance_works_work_date ON maintenance.maintenance_works(work_date);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_maintenance_works_created_at ON maintenance.maintenance_works(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_maintenance_works_updated_at ON maintenance.maintenance_works(updated_at);

-- Таблица для хранения данных о приборах учета
CREATE TABLE maintenance.meters (
    id SERIAL PRIMARY KEY,                                                     -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                               -- UUID для внешней интеграции и обеспечения уникальности записи
    object_id INTEGER REFERENCES real_estate.objects(id),                      -- Внешний ключ на объект недвижимости, ссылается на таблицу real_estate.objects
    equipment_id INTEGER REFERENCES maintenance.equipment(id),                  -- Внешний ключ на оборудование, ссылается на таблицу maintenance.equipment
    contract_id INTEGER REFERENCES reference.contracts(id),                    -- Внешний ключ на контракт, ссылается на таблицу reference.contracts
    meter_type VARCHAR(255) NOT NULL,                                            -- Тип счетчика (например, водяной, электрический), ограничено 255 символами
    serial_number VARCHAR(255),                                                 -- Серийный номер счетчика, ограничено 255 символами
    installation_date DATE,                                                     -- Дата установки счетчика
    comments TEXT,                                                              -- Дополнительные комментарии о счетчике
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                             -- Дата и время создания записи, по умолчанию текущая дата и время
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                              -- Дата и время последнего обновления записи
);

-- Индекс на поле object_id для улучшения производительности запросов по объектам недвижимости
CREATE INDEX idx_meters_object_id ON maintenance.meters(object_id);

-- Индекс на поле equipment_id для улучшения производительности запросов по оборудованию
CREATE INDEX idx_meters_equipment_id ON maintenance.meters(equipment_id);

-- Индекс на поле contract_id для улучшения производительности запросов по контрактам
CREATE INDEX idx_meters_contract_id ON maintenance.meters(contract_id);

-- Индекс на поле meter_type для ускорения запросов по типам счетчиков
CREATE INDEX idx_meters_meter_type ON maintenance.meters(meter_type);

-- Индекс на поле serial_number для ускорения запросов по серийным номерам счетчиков
CREATE INDEX idx_meters_serial_number ON maintenance.meters(serial_number);

-- Индекс на поле installation_date для улучшения запросов по дате установки
CREATE INDEX idx_meters_installation_date ON maintenance.meters(installation_date);

-- Индекс на поле created_at для ускорения запросов по дате создания записи
CREATE INDEX idx_meters_created_at ON maintenance.meters(created_at);

-- Индекс на поле updated_at для ускорения запросов по дате обновления записи
CREATE INDEX idx_meters_updated_at ON maintenance.meters(updated_at);

-- Таблица для хранения данных о показаниях приборов учета
CREATE TABLE maintenance.meter_readings (
    id SERIAL PRIMARY KEY,                                                     -- Автоинкрементный ID для уникальной идентификации записи
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                               -- UUID для внешней интеграции и обеспечения уникальности записи
    meter_id INTEGER NOT NULL REFERENCES maintenance.meters(id),                -- Внешний ключ на счетчик, ссылается на таблицу maintenance.meters
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),              -- Внешний ключ на объект недвижимости, ссылается на таблицу real_estate.objects
    act_id INTEGER REFERENCES reference.acts(id),                              -- Внешний ключ на акт, ссылается на таблицу reference.acts (не обязательное поле)
    performer_id INTEGER REFERENCES reference.legal_entities(id),              -- Внешний ключ на исполнителя, ссылается на таблицу reference.legal_entities
    reading_value DECIMAL(15, 2) NOT NULL,                                     -- Значение показания счетчика, ограничено 15 знаками (2 знака после запятой)
    reading_date DATE NOT NULL,                                                -- Дата снятия показания, обязательное поле
    comments TEXT,                                                             -- Дополнительные комментарии
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                             -- Дата и время создания записи, по умолчанию текущая дата и время
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP                              -- Дата и время последнего обновления записи, по умолчанию текущая дата и время
);

-- Индекс на поле meter_id для ускорения запросов по счетчикам
CREATE INDEX idx_meter_readings_meter_id ON maintenance.meter_readings(meter_id);

-- Индекс на поле object_id для ускорения запросов по объектам недвижимости
CREATE INDEX idx_meter_readings_object_id ON maintenance.meter_readings(object_id);

-- Индекс на поле act_id для ускорения запросов по актам
CREATE INDEX idx_meter_readings_act_id ON maintenance.meter_readings(act_id);

-- Индекс на поле performer_id для ускорения запросов по исполнителям
CREATE INDEX idx_meter_readings_performer_id ON maintenance.meter_readings(performer_id);

-- Индекс на поле reading_date для ускорения запросов по дате снятия показания
CREATE INDEX idx_meter_readings_reading_date ON maintenance.meter_readings(reading_date);

-- Индекс на поле created_at для улучшения производительности запросов по дате создания
CREATE INDEX idx_meter_readings_created_at ON maintenance.meter_readings(created_at);

-- Индекс на поле updated_at для улучшения запросов по дате обновления записи
CREATE INDEX idx_meter_readings_updated_at ON maintenance.meter_readings(updated_at);

-- Модуль "Пользователи, роли, логгирование"
CREATE SCHEMA IF NOT EXISTS auth;

-- Таблица для хранения основной информации о пользователях.
CREATE TABLE auth.users (
    id SERIAL PRIMARY KEY,                                                        -- Автоинкрементный ID для уникальной идентификации пользователя
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                                  -- UUID для уникальности записи и внешней интеграции
    username VARCHAR(255) UNIQUE NOT NULL,                                         -- Имя пользователя, уникальное и обязательное поле
    password VARCHAR(255) NOT NULL,                                                -- Пароль пользователя, обязательное поле
    full_name VARCHAR(255),                                                       -- Полное имя пользователя, необязательное поле
    email VARCHAR(255),                                                           -- Электронная почта пользователя, необязательное поле
    status BOOLEAN DEFAULT TRUE,                                                  -- Статус пользователя, по умолчанию активен
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                               -- Дата и время создания записи, по умолчанию текущая дата и время
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                               -- Дата и время последнего обновления записи, по умолчанию текущая дата и время
    CONSTRAINT username_check CHECK (username ~ '^[a-zA-Z0-9_]+$')                -- Ограничение на формат username: только буквы, цифры и символ подчеркивания
);

-- Индекс на поле username для ускорения поиска по имени пользователя
CREATE INDEX idx_users_username ON auth.users(username);

-- Индекс на поле email для ускорения поиска по электронной почте
CREATE INDEX idx_users_email ON auth.users(email);

-- Триггер для автоматического обновления поля updated_at при изменении записи
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;                                          -- Обновление поля updated_at текущей датой и временем
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_users_updated_at
BEFORE UPDATE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Таблица для хранения ролей
CREATE TABLE auth.roles (
    id SERIAL PRIMARY KEY,                                                        -- Автоинкрементный ID для уникальной идентификации роли
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),                                  -- UUID для уникальности записи и внешней интеграции
    role_name VARCHAR(255) UNIQUE NOT NULL,                                        -- Имя роли, уникальное и обязательное поле
    description TEXT,                                                             -- Описание роли, необязательное поле
    CONSTRAINT role_name_check CHECK (role_name ~ '^[a-zA-Z0-9_]+$')               -- Ограничение на формат role_name: только буквы, цифры и символ подчеркивания
);

-- Индекс на поле role_name для ускорения поиска по имени роли
CREATE INDEX idx_roles_role_name ON auth.roles(role_name);

-- Триггер для автоматического обновления поля updated_at (если добавим поле updated_at)
-- -- данный триггер можно использовать для будущего, если потребуется отслеживать обновления записей ролей
-- CREATE OR REPLACE FUNCTION update_roles_timestamp() RETURNS TRIGGER AS $$
-- BEGIN
--     NEW.updated_at = CURRENT_TIMESTAMP;                                          -- Обновление поля updated_at текущей датой и временем
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_update_roles_updated_at
-- BEFORE UPDATE ON auth.roles
-- FOR EACH ROW
-- EXECUTE FUNCTION update_roles_timestamp();                                     -- Срабатывает при каждом обновлении записи

-- Таблица для связи пользователей и ролей
-- Таблица для хранения связей между пользователями и ролями
CREATE TABLE auth.user_roles (
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,  -- Внешний ключ, ссылающийся на таблицу пользователей (при удалении пользователя записи будут каскадно удаляться)
    role_id INTEGER REFERENCES auth.roles(id) ON DELETE CASCADE,  -- Внешний ключ, ссылающийся на таблицу ролей (при удалении роли записи будут каскадно удаляться)
    PRIMARY KEY (user_id, role_id),  -- Составной первичный ключ для обеспечения уникальности сочетания пользователя и роли
    CONSTRAINT user_roles_check CHECK (user_id > 0 AND role_id > 0) -- Проверка, чтобы user_id и role_id всегда были положительными
);

-- Индекс для ускорения поиска связей между пользователями и ролями
CREATE INDEX idx_user_roles_user_id ON auth.user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON auth.user_roles(role_id);

-- Таблица для прав доступа (optional)
-- Таблица для хранения прав доступа, назначаемых ролям
CREATE TABLE auth.role_permissions (
    role_id INTEGER REFERENCES auth.roles(id) ON DELETE CASCADE,  -- Внешний ключ, ссылающийся на таблицу ролей (при удалении роли записи будут каскадно удаляться)
    permission_type VARCHAR(50) NOT NULL,                         -- Тип разрешения (например, 'read', 'write', 'delete')
    object_name VARCHAR(255) NOT NULL,                            -- Название объекта, к которому применяется разрешение (например, 'documents', 'users')
    PRIMARY KEY (role_id, permission_type, object_name),          -- Составной первичный ключ для обеспечения уникальности сочетания роли, типа разрешения и объекта
    CONSTRAINT permission_type_check CHECK (permission_type IN ('read', 'write', 'delete')) -- Проверка допустимых значений для типа разрешения
);

-- Индексы для ускорения поиска прав доступа по роли и объекту
CREATE INDEX idx_role_permissions_role_id ON auth.role_permissions(role_id);
CREATE INDEX idx_role_permissions_object_name ON auth.role_permissions(object_name);


-- Модуль "BIM"
CREATE SCHEMA IF NOT EXISTS bim;

CREATE TABLE bim.ifc_objects (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    ifc_id VARCHAR UNIQUE NOT NULL, -- GlobalId из IFC
    name VARCHAR, -- Имя объекта (Name)
    description TEXT, -- Описание объекта
    type VARCHAR NOT NULL, -- Тип объекта (например, IfcWall)
    placement JSONB, -- Пространственное размещение (данные из IfcLocalPlacement)
    geometry_type VARCHAR, -- Тип геометрии (BRep, Mesh и т.д.)
    geometry_data TEXT, -- Геометрия объекта (например, в формате BRep или Mesh)
    attributes JSONB, -- Дополнительные атрибуты (например, Property Sets)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX idx_ifc_objects_ifc_id ON bim.ifc_objects (ifc_id);
CREATE INDEX idx_ifc_objects_type ON bim.ifc_objects (type);

CREATE TABLE bim.ifc_materials (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    object_id INTEGER NOT NULL REFERENCES bim.ifc_objects(id), -- Связь с объектом
    material_name VARCHAR NOT NULL, -- Название материала
    density DECIMAL, -- Плотность материала
    thermal_conductivity DECIMAL, -- Теплопроводность
    specific_heat DECIMAL, -- Удельная теплоемкость
    additional_properties JSONB, -- Другие свойства материала
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


REATE TABLE bim.ifc_properties (
    id SERIAL PRIMARY KEY,
    object_id INTEGER NOT NULL REFERENCES bim.ifc_objects(id), -- Связь с объектом
    property_set_name VARCHAR, -- Название набора свойств (например, Pset_WallCommon)
    property_name VARCHAR NOT NULL, -- Название свойства
    property_value TEXT NOT NULL, -- Значение свойства
    property_type VARCHAR NOT NULL, -- Тип данных свойства (String, Number, Boolean)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX idx_ifc_properties_object_id ON bim.ifc_properties (object_id);
CREATE INDEX idx_ifc_properties_property_name ON bim.ifc_properties (property_name);

CREATE TABLE bim.ifc_relationships (
    id SERIAL PRIMARY KEY,
    parent_object_id INTEGER NOT NULL REFERENCES bim.ifc_objects(id), -- Родительский объект
    child_object_id INTEGER NOT NULL REFERENCES bim.ifc_objects(id), -- Дочерний объект
    relationship_type VARCHAR NOT NULL, -- Тип отношения (например, Aggregates, Contains)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ifc_relationships_parent ON bim.ifc_relationships (parent_object_id);
CREATE INDEX idx_ifc_relationships_child ON bim.ifc_relationships (child_object_id);

-- Модуль "ГИС"
CREATE SCHEMA IF NOT EXISTS gis;

-- Таблица для хранения слоев данных в ГИС
CREATE TABLE gis.layers (
    id SERIAL PRIMARY KEY,                                -- Уникальный идентификатор слоя
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),         -- UUID для уникальной идентификации слоя
    layer_name VARCHAR(255) NOT NULL,                     -- Название слоя
    layer_type VARCHAR(50) NOT NULL,                      -- Тип слоя (например, "polygon", "point", "line")
    description TEXT,                                     -- Описание слоя
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,       -- Время создания слоя
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,       -- Время последнего обновления
    spatial_data GEOMETRY,                                -- Пространственные данные (геометрия)
    comments TEXT                                         -- Дополнительные комментарии
);

-- Индекс на геометрическое поле для ускорения операций с пространственными данными
CREATE INDEX idx_layers_spatial_data ON gis.layers USING GIST(spatial_data);

-- Таблица для хранения метаданных объектов ГИС
CREATE TABLE gis.metadata (
    id SERIAL PRIMARY KEY,                                -- Уникальный идентификатор записи метаданных
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),         -- UUID для метаданных
    layer_id INTEGER REFERENCES gis.layers(id),           -- Внешний ключ, ссылающийся на слой
    object_id INTEGER NOT NULL,                           -- Идентификатор объекта (например, здания, земельного участка)
    object_name VARCHAR(255),                             -- Название объекта
    object_type VARCHAR(50),                              -- Тип объекта (например, "building", "land")
    spatial_data GEOMETRY,                                -- Пространственные данные объекта (геометрия)
    metadata JSONB,                                      -- Дополнительные метаданные объекта в формате JSON
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,       -- Дата создания записи метаданных
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP        -- Дата последнего обновления записи
);

-- Индекс для улучшения производительности запросов по объектам и слоям
CREATE INDEX idx_metadata_layer_id ON gis.metadata(layer_id);
CREATE INDEX idx_metadata_object_id ON gis.metadata(object_id);
CREATE INDEX idx_metadata_spatial_data ON gis.metadata USING GIST(spatial_data);

-- Таблица для хранения информации о пространственных запросах и их результатах
CREATE TABLE gis.spatial_queries (
    id SERIAL PRIMARY KEY,                                -- Уникальный идентификатор запроса
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),         -- UUID для запроса
    query_name VARCHAR(255) NOT NULL,                     -- Название запроса
    query_text TEXT NOT NULL,                             -- Текст самого запроса (SQL запрос или описание)
    result_data GEOMETRY,                                 -- Результаты выполнения запроса в виде геометрических данных
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,      -- Время выполнения запроса
    comments TEXT                                         -- Дополнительные комментарии
);

-- Индекс для ускорения поиска по результатам пространственных запросов
CREATE INDEX idx_spatial_queries_result_data ON gis.spatial_queries USING GIST(result_data);


-- Таблица для хранения точек интереса (POI)
CREATE TABLE gis.points_of_interest (
    id SERIAL PRIMARY KEY,                                -- Уникальный идентификатор точки интереса
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),         -- UUID для точки интереса
    point_name VARCHAR(255) NOT NULL,                     -- Название точки интереса
    coordinates GEOMETRY(Point, 4326) NOT NULL,            -- Географические координаты точки (тип данных GEOMETRY)
    description TEXT,                                     -- Описание точки
    category VARCHAR(100),                                 -- Категория точки интереса (например, "здание", "магазин", "школа")
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,       -- Время создания записи
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP        -- Время последнего обновления
);

-- Индекс для улучшения поиска точек интереса по координатам
CREATE INDEX idx_poi_coordinates ON gis.points_of_interest USING GIST(coordinates);



-- Модуль "Экономика недвижимости"
CREATE SCHEMA IF NOT EXISTS real_estate_economics;

-- Таблица для хранения тарифов аренды
CREATE TABLE real_estate_economics.rental_rates (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости
    rate_type VARCHAR(50) NOT NULL,  -- Тип тарифа (например, ежемесячный, квартальный)
    rate DECIMAL(15, 2) NOT NULL,  -- Тариф, с точностью до 2 знаков после запятой
    currency VARCHAR(3) NOT NULL,  -- Валюта (например, USD, EUR)
    start_date DATE NOT NULL,  -- Дата начала действия тарифа
    end_date DATE,  -- Дата окончания действия тарифа (если есть)
    comments TEXT,  -- Дополнительная информация
    CONSTRAINT fk_object FOREIGN KEY (object_id) REFERENCES real_estate.objects(id)
);

CREATE TABLE reference.utility_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,  -- Название типа услуги (например, вода, электричество)
    description TEXT  -- Дополнительное описание
);

-- Таблица для хранения тарифов на коммунальные услуги
CREATE TABLE real_estate_economics.utility_rates (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости
    utility_type INTEGER REFERENCES reference.utility_types(id),  -- Тип коммунальной услуги (например, вода, электричество)
    rate DECIMAL(15, 2) NOT NULL,  -- Тариф, с точностью до 2 знаков после запятой
    currency VARCHAR(3) NOT NULL,  -- Валюта (например, USD, EUR)
    start_date DATE NOT NULL,  -- Дата начала действия тарифа
    end_date DATE,  -- Дата окончания действия тарифа (если есть)
    comments TEXT,  -- Дополнительная информация
    CONSTRAINT fk_object FOREIGN KEY (object_id) REFERENCES real_estate.objects(id)
);

-- Таблица для учета доходов
CREATE TABLE reference.income_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,  -- Название типа дохода (например, аренда, продажа)
    description TEXT  -- Дополнительное описание типа дохода
);


CREATE TABLE real_estate_economics.income (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости
    income_type INTEGER NOT NULL REFERENCES reference.income_types(id),  -- Ссылка на тип дохода
    amount DECIMAL(15, 2) NOT NULL,  -- Сумма дохода, с точностью до 2 знаков после запятой
    currency VARCHAR(3) NOT NULL,  -- Валюта (например, USD, EUR)
    transaction_date DATE NOT NULL,  -- Дата транзакции
    document_id INTEGER REFERENCES reference.contracts(id),  -- Ссылка на документ (например, договор аренды)
    tax DECIMAL(15, 2),  -- Налог с дохода
    commission DECIMAL(15, 2),  -- Комиссия за сделку
    comments TEXT,  -- Дополнительная информация
    CONSTRAINT fk_object FOREIGN KEY (object_id) REFERENCES real_estate.objects(id),
    CONSTRAINT fk_income_type FOREIGN KEY (income_type) REFERENCES reference.income_types(id)  -- Ссылка на таблицу типов доходов
);

-- Индекс на поле object_id для ускорения выборки по объекту недвижимости
CREATE INDEX idx_income_object_id ON real_estate_economics.income(object_id);

-- Индекс на поле income_type для ускорения выборки по типу дохода
CREATE INDEX idx_income_type ON real_estate_economics.income(income_type);

-- Индекс на поле transaction_date для ускорения выборки по дате транзакции
CREATE INDEX idx_income_transaction_date ON real_estate_economics.income(transaction_date);

-- Индекс на поле document_id для быстрого поиска по документам
CREATE INDEX idx_income_document_id ON real_estate_economics.income(document_id);



-- Таблица для учета расходов
CREATE TABLE real_estate_economics.expense (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости
    expense_type expense_type NOT NULL,  -- Тип расхода (обслуживание, ремонт, коммунальные услуги, прочее)
    amount DECIMAL NOT NULL,  -- Сумма расхода
    currency VARCHAR(3) NOT NULL,  -- Валюта
    transaction_date DATE NOT NULL,  -- Дата транзакции
    document_id INTEGER REFERENCES reference.contracts(id),  -- Ссылка на документ (например, акт или договор)
    comments TEXT  -- Дополнительная информация
);

-- Индекс на поле object_id для ускорения выборки по объекту недвижимости
CREATE INDEX idx_expense_object_id ON real_estate_economics.expense(object_id);

-- Индекс на поле expense_type для ускорения выборки по типу расхода
CREATE INDEX idx_expense_type ON real_estate_economics.expense(expense_type);

-- Индекс на поле transaction_date для ускорения выборки по дате транзакции
CREATE INDEX idx_expense_transaction_date ON real_estate_economics.expense(transaction_date);

-- Индекс на поле document_id для быстрого поиска по документам
CREATE INDEX idx_expense_document_id ON real_estate_economics.expense(document_id);

-- Таблица для хранения налоговых ставок
CREATE TABLE real_estate_economics.tax_rates (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    tax_type VARCHAR NOT NULL,  -- Тип налога (например, налог на имущество)
    rate DECIMAL NOT NULL,  -- Ставка налога
    start_date DATE NOT NULL,  -- Дата начала действия ставки
    end_date DATE,  -- Дата окончания действия ставки (если есть)
    comments TEXT  -- Дополнительная информация
);

-- Индекс на поле tax_type для ускорения выборки по типу налога
CREATE INDEX idx_tax_rates_tax_type ON real_estate_economics.tax_rates(tax_type);

-- Индекс на поле start_date для ускорения выборки по дате начала действия ставки
CREATE INDEX idx_tax_rates_start_date ON real_estate_economics.tax_rates(start_date);

-- Индекс на поле end_date для ускорения выборки по дате окончания действия ставки
CREATE INDEX idx_tax_rates_end_date ON real_estate_economics.tax_rates(end_date);


-- Таблица для транзакций (учет всех финансовых операций)
CREATE TABLE real_estate_economics.transactions (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    transaction_type VARCHAR NOT NULL,  -- Тип транзакции (доход, расход, перерасчет и т.д.)
    amount DECIMAL NOT NULL,  -- Сумма транзакции
    currency VARCHAR(3) NOT NULL,  -- Валюта
    transaction_date DATE NOT NULL,  -- Дата транзакции
    object_id INTEGER REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости
    contract_id INTEGER REFERENCES reference.contracts(id),  -- Ссылка на договор (если применимо)
    tax_rate_id INTEGER REFERENCES real_estate_economics.tax_rates(id),  -- Ссылка на налоговую ставку
    income_id INTEGER REFERENCES real_estate_economics.income(id),  -- Ссылка на доход (если применимо)
    expense_id INTEGER REFERENCES real_estate_economics.expense(id),  -- Ссылка на расход (если применимо)
    comments TEXT  -- Дополнительная информация
);

-- Индекс на поле transaction_type для ускорения выборки по типу транзакции
CREATE INDEX idx_transactions_transaction_type ON real_estate_economics.transactions(transaction_type);

-- Индекс на поле transaction_date для ускорения выборки по дате транзакции
CREATE INDEX idx_transactions_transaction_date ON real_estate_economics.transactions(transaction_date);

-- Индекс на поле object_id для ускорения выборки по объекту недвижимости
CREATE INDEX idx_transactions_object_id ON real_estate_economics.transactions(object_id);

-- Индекс на поле contract_id для ускорения выборки по контрактам
CREATE INDEX idx_transactions_contract_id ON real_estate_economics.transactions(contract_id);

-- Индекс на поле tax_rate_id для ускорения выборки по налоговым ставкам
CREATE INDEX idx_transactions_tax_rate_id ON real_estate_economics.transactions(tax_rate_id);

-- Индекс на поле income_id для ускорения выборки по доходам
CREATE INDEX idx_transactions_income_id ON real_estate_economics.transactions(income_id);

-- Индекс на поле expense_id для ускорения выборки по расходам
CREATE INDEX idx_transactions_expense_id ON real_estate_economics.transactions(expense_id);

-- Таблица для хранения расчетных метрик
CREATE TABLE real_estate_economics.financial_metrics (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    object_id INTEGER NOT NULL REFERENCES real_estate.objects(id),  -- Ссылка на объект недвижимости
    metric_type VARCHAR NOT NULL,  -- Тип метрики (например, ARI, NOI, кап. доходность)
    value DECIMAL NOT NULL,  -- Значение метрики
    metric_date DATE NOT NULL,  -- Дата расчета
    comments TEXT  -- Дополнительная информация
);

-- Индекс на поле object_id для ускорения выборки по объекту недвижимости
CREATE INDEX idx_financial_metrics_object_id ON real_estate_economics.financial_metrics(object_id);

-- Индекс на поле metric_type для ускорения выборки по типу метрики
CREATE INDEX idx_financial_metrics_metric_type ON real_estate_economics.financial_metrics(metric_type);

-- Индекс на поле metric_date для ускорения выборки по дате расчета
CREATE INDEX idx_financial_metrics_metric_date ON real_estate_economics.financial_metrics(metric_date);


-- Функция для обновления времени последнего изменения
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем поле updated_at на текущее время при каждом обновлении строки
    NEW.updated_at = CURRENT_TIMESTAMP;  
    RETURN NEW;  -- Возвращаем обновленную строку
END;
$$ LANGUAGE plpgsql;  -- Используем язык plpgsql для создания функции


-- Триггер для всех таблиц, которые содержат поле updated_at
DO $$ 
DECLARE
    tbl_name text;  -- Переменная для хранения имени таблицы
BEGIN
    -- Для каждой таблицы в схеме, которая содержит поле updated_at
    FOR tbl_name IN 
        SELECT table_name
        FROM information_schema.columns
        WHERE column_name = 'updated_at' AND table_schema = 'public'  -- Проверяем таблицы в схеме public
    LOOP
        -- Создаем триггер для каждой таблицы
        EXECUTE format('
            CREATE TRIGGER %I_set_updated_at
            BEFORE UPDATE ON %I
            FOR EACH ROW
            EXECUTE FUNCTION update_timestamp();
        ', tbl_name || '_updated_at', tbl_name);  -- Генерируем триггер для каждой таблицы
    END LOOP;
END $$;

-- Функция для пересчета общей площади объекта недвижимости
CREATE OR REPLACE FUNCTION calculate_total_area()
RETURNS TRIGGER AS $$
BEGIN
    -- Суммируем площади всех помещений, связанных с данным объектом
    NEW.total_area := (SELECT COALESCE(SUM(room_area), 0) 
                        FROM real_estate.room_characteristics 
                        WHERE object_id = NEW.id);  -- Суммируем площади всех помещений
    RETURN NEW;  -- Возвращаем обновленную строку
END;
$$ LANGUAGE plpgsql;  -- Используем язык plpgsql для создания функции

-- Триггер на вставку, обновление или удаление данных о помещениях, чтобы пересчитать общую площадь
CREATE TRIGGER update_total_area
AFTER INSERT OR UPDATE OR DELETE ON real_estate.room_characteristics  -- Срабатывает после вставки, обновления или удаления данных
FOR EACH ROW
EXECUTE FUNCTION calculate_total_area();  -- Вызываем функцию для пересчета общей площади

-- Функция для обновления статуса аренды при истечении срока аренды
CREATE OR REPLACE FUNCTION update_rental_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Если дата окончания аренды меньше текущей даты, обновляем статус на "expired"
    IF NEW.rental_end_date < CURRENT_DATE THEN
        NEW.rental_status := 'expired';  -- Статус аренды меняется на "истекла"
    END IF;
    RETURN NEW;  -- Возвращаем обновленную строку
END;
$$ LANGUAGE plpgsql;  -- Используем язык plpgsql для создания функции

-- Триггер на обновление данных аренды
CREATE TRIGGER rental_status_update
BEFORE UPDATE ON legal_accounting.rental  -- Срабатывает до обновления данных аренды
FOR EACH ROW
EXECUTE FUNCTION update_rental_status();  -- Вызываем функцию для обновления статуса аренды


-- Пример функции для логирования изменений
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Вставляем запись в таблицу журнала изменений (change_log)
    INSERT INTO change_log (table_name, action_type, old_data, new_data, changed_by, changed_at)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW), CURRENT_USER, CURRENT_TIMESTAMP); 
    RETURN NEW;  -- Возвращаем обновленную строку
END;
$$ LANGUAGE plpgsql;  -- Используем язык plpgsql для создания функции

-- Пример триггера для таблицы объектов недвижимости
CREATE TRIGGER log_object_changes
AFTER INSERT OR UPDATE OR DELETE ON real_estate.objects  -- Срабатывает после вставки, обновления или удаления записи
FOR EACH ROW
EXECUTE FUNCTION log_changes();  -- Вызываем функцию для логирования изменений


-- Функция для обновления времени последнего изменения
CREATE OR REPLACE FUNCTION update_bim_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Применение триггера на таблицы
CREATE TRIGGER set_updated_at_ifc_objects
BEFORE UPDATE ON bim.ifc_objects
FOR EACH ROW
EXECUTE FUNCTION update_bim_timestamp();

CREATE TRIGGER set_updated_at_ifc_properties
BEFORE UPDATE ON bim.ifc_properties
FOR EACH ROW
EXECUTE FUNCTION update_bim_timestamp();

CREATE TRIGGER set_updated_at_ifc_relationships
BEFORE UPDATE ON bim.ifc_relationships
FOR EACH ROW
EXECUTE FUNCTION update_bim_timestamp();


-- Функция для каскадного удаления
CREATE OR REPLACE FUNCTION cascade_delete_ifc_object()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM bim.ifc_properties WHERE object_id = OLD.id;
    DELETE FROM bim.ifc_relationships WHERE parent_object_id = OLD.id OR child_object_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Триггер для каскадного удаления
CREATE TRIGGER cascade_delete_ifc_objects
AFTER DELETE ON bim.ifc_objects
FOR EACH ROW
EXECUTE FUNCTION cascade_delete_ifc_object();


-- Функция для пересчета площади (пример для IfcWall)
CREATE OR REPLACE FUNCTION recalculate_metrics()
RETURNS TRIGGER AS $$
BEGIN
    -- Пример пересчета свойства "площадь"
    UPDATE bim.ifc_properties
    SET property_value = (SELECT SUM(ST_Area(geometry_data::geometry))
                          FROM bim.ifc_objects
                          WHERE type = 'IfcWall' AND id = NEW.object_id)
    WHERE object_id = NEW.object_id AND property_name = 'WallArea';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для пересчета метрик
CREATE TRIGGER update_metrics_on_change
AFTER INSERT OR UPDATE ON bim.ifc_objects
FOR EACH ROW
EXECUTE FUNCTION recalculate_metrics();

