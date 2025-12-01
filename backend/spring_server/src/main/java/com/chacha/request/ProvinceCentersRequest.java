package com.chacha.request;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

@Schema(description = "광역시·도 경계 중심점 리스트 조회 요청")
@Getter
@Setter
public class ProvinceCentersRequest {

    @Schema(description = "광역시·도 코드", example = "KR-INCHEON", required = true)
    private String provinceCode;

    @Schema(description = "리밋", example = "100")
    private Integer limit;

    @Schema(description = "오프셋", example = "0")
    private Integer offset;
}
