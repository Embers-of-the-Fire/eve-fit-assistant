def into_i18n(field, en: str, zh: str = None, **kwargs):
    field.en = en
    if zh:
        field.zh = zh
