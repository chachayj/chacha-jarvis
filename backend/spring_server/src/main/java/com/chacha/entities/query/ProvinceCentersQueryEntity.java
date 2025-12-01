package com.chacha.entities.query;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;
import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "param: province_centers_query",
    entityType = EntityType.QUERY_DATAS,
    description = "광역시·도 경계 중심점 목록 조회 파라미터"
)
@Getter
@Setter
public class ProvinceCentersQueryEntity {
    private String  provinceCode;  // 예: "KR-INCHEON"
    private Integer limit;         // null 가능
    private Integer offset;        // null 가능
}
