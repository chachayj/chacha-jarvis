package com.chacha.response;

import java.util.List;

import com.chacha.dto.DistrictsDTO;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

@Schema(description = "도/광역시별 구(區) 목록 조회 응답")
@Getter
@Setter
public class DistrictListResponse {

    @Schema(description = "광역시·도 코드", example = "KR-SEOUL")
    private String provinceCode;

    @Schema(description = "구(區) 목록")
    private List<DistrictsDTO> districts;
}
