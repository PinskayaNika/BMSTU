from typing import Optional

import numpy as np


class Simplexx:
    def __init__(self, a: np.ndarray, b: np.ndarray, lambdas: np.ndarray, signs: np.ndarray):
        self.matr = a
        self.b = b
        self.lambdas = lambdas
        self.signs = signs.reshape(signs.shape[0], 1)
        self.tbl = None
        self.header_top = []
        self.header_left = []
        self.iterations = []

    def create_simplex_table(self) -> np.ndarray:
        row_num = self.matr.shape[0]
        col_num = self.matr.shape[1]

        self.header_top = []
        i = 0
        while i < col_num:
            self.header_top.append(f'x_{i}')
            i += 1

        self.header_left = []
        j = 0
        while j < row_num:
            # продолжаем счет переменных
            self.header_left.append(f'x_{i + j}')
            j += 1

        tbl = self.matr

        # добавляем колонку b'шек слева
        tbl = np.hstack((self.b, tbl))

        # добавляем строку лямбд внизу
        pos = 0
        additional_zero_elem = 0
        lambdas = np.insert(self.lambdas, pos, additional_zero_elem, axis=0)
        tbl = np.vstack((tbl, lambdas))
        return tbl

    def is_acceptable_solution(self) -> bool:
        # в столбце свободных членов все эл-ты положительные
        return True

    # поиск резрешающего столбца
    def find_determining_column(self) -> Optional[int]:
        lambdas_row = self.tbl[self._get_rows() - 1:]
        labdas_row_len = lambdas_row.shape[1]
        i = 0
        while i < labdas_row_len:
            if float(lambdas_row[0, i]) > 0:
                # ищем первый положительный элемент
                # возвращаем разрешающий столбец
                return i
            i += 1
        return None

    # поиск резрешающей строки
    def find_determining_row(self, determining_col: int) -> Optional[int]:
        # Найдем минимальное положительное отношение элемента свободных членов
        # si0 к соответствующем эле- менту в разрешающем столбце
        min_relation = 999999
        determining_row = None
        i = 0
        while i < self._get_rows() - 1:
            if 0 == self._at(i, determining_col):
                i += 1
                continue

            curr_relation = self._at(i, 0) / self._at(i, determining_col)
            if curr_relation < min_relation:
                min_relation = curr_relation
                determining_row = i
            i += 1
        # разрешающая строка
        return determining_row

    def change_basis(self, row: int, col: int):
        pass

    def run(self) -> (dict, float):
        self.tbl = self.create_simplex_table()

        if self.is_acceptable_solution():
            # Так как все элементы столбца si0 неотрицательны, имеем опорное решение
            variables = self.get_variables_mapping()
            value = self.target_func()
            self.iterations.append((0, variables, value))

            iters = 0
            while True:
                print(f'iters: {iters}')

                determining_col = self.find_determining_column()
                print(f'determining col: {determining_col}')
                if determining_col is None:
                    print('determining col is None')
                    break

                determining_row = self.find_determining_row(determining_col)
                print(f'determining col: {determining_col}')

                if determining_row is None:
                    print('determining row is None')
                    break

                self.change_basis(determining_row, determining_col)


        return self.iterations

    def target_func(self) -> float:
        # так как все свобоные переменные = 0,
        # то ответ лежит в первой клетке подвала таблицы
        rows = self.tbl.shape[0]
        return self.tbl[rows - 1, 0]

    def get_variables_mapping(self) -> dict:
        res = dict()
        for x_i in self.header_top:
            if 'b' == x_i:
                continue
            else:
                res[x_i] = 0
        j = 0
        for x_j in self.header_left:
            res[x_j] = self.tbl[j, 0]
            j += 1
        return res

    def _at(self, row, col) -> float:
        return self.tbl[row, col]

    def _get_rows(self) -> int:
        return self.tbl.shape[0]

    def _get_cols(self) -> int:
        return self.tbl.shape[0]

    def _to_column(self, xs: np.ndarray) -> np.ndarray:
        return xs.reshape(xs.shape[0], 1)


def main():
    a = np.array([[2, 1, 1],
                  [1, 2, 0],
                  [0, 0.5, 1]])
    b = np.array([[4],
                  [6],
                  [2]])
    signs = np.array([['<='],
                      ['<='],
                      ['<=']])
    lambdas = np.array([2, 8, 3])   # TODO ищем минимум, хотя в задании указан максимум

    s = Simplexx(a, b, lambdas, signs)
    variables, value = s.run()
    print(variables)
    print(f'F = {value}')


if __name__ == '__main__':
    main()
