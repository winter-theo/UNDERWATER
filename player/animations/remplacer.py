#!/usr/bin/env python3
"""Remplace toutes les occurrences d'une chaîne par une autre dans un fichier .tres."""

import argparse
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(
        description="Remplace chaque occurrence d'une chaîne par une autre dans un fichier .tres."
    )
    parser.add_argument("fichier", help="Chemin du fichier .tres (relatif ou absolu)")
    parser.add_argument("ancienne", help="Chaîne à rechercher")
    parser.add_argument("nouvelle", help="Chaîne de remplacement")
    parser.add_argument(
        "--backup",
        action="store_true",
        help="Crée une sauvegarde (.bak) avant de modifier le fichier",
    )
    args = parser.parse_args()

    chemin = Path(args.fichier)

    if not chemin.is_file():
        print(f"Erreur : fichier introuvable : {chemin}", file=sys.stderr)
        sys.exit(1)

    # Lecture en binaire puis décodage : préserve les fins de ligne exactes
    # (pas de conversion \r\n -> \n) pour éviter des diffs parasites.
    contenu = chemin.read_bytes().decode("utf-8")
    nb = contenu.count(args.ancienne)

    if nb == 0:
        print(f"Aucune occurrence de « {args.ancienne} » trouvée. Fichier inchangé.")
        return

    if args.backup:
        sauvegarde = chemin.with_name(chemin.name + ".bak")
        sauvegarde.write_bytes(contenu.encode("utf-8"))
        print(f"Sauvegarde : {sauvegarde}")

    contenu = contenu.replace(args.ancienne, args.nouvelle)
    chemin.write_bytes(contenu.encode("utf-8"))

    print(f"{nb} occurrence(s) remplacée(s) dans {chemin}.")


if __name__ == "__main__":
    main()
