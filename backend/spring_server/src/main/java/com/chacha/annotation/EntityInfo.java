package com.chacha.annotation;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.annotation.ElementType;

/**
 * MyBatis 기반 Entity 클래스에 테이블/뷰/조인 정보를 명시하기 위한 메타 어노테이션
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface EntityInfo {
    String tableName();             // 테이블명, 뷰명, 조인 키 등
    EntityType entityType() default EntityType.TABLE;
    String description() default ""; // 설명 문구
}
