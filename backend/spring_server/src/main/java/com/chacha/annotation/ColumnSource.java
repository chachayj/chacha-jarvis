package com.chacha.annotation;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.annotation.ElementType;

/**
 * Entity 필드가 어떤 테이블/컬럼으로부터 매핑되었는지 명시
 */
@Retention(RetentionPolicy.CLASS) // 또는 RUNTIME, 리플렉션 활용할 거면
@Target(ElementType.FIELD)
public @interface ColumnSource {
    String value();
}