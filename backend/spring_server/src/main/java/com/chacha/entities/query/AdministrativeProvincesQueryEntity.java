package com.chacha.entities.query;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;
import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "param: administrative_provinces_query",
    entityType = EntityType.QUERY_DATAS,
    description = "국가별 광역시·도 목록 조회 파라미터"
)
@Getter
@Setter
public class AdministrativeProvincesQueryEntity {
    private String countryCode; // 예: "KR"
}
