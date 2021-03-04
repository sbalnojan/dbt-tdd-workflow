{% macro test_dummy(model) %}

{% set test_in_env = kwargs.get('env') %}


 {%- if target.name == 'ci' -%}

 select 'huhu'

 {%- else -%}

   select 0

 {%- endif -%}

{% endmacro %}
